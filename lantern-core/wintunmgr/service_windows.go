//go:build windows

package wintunmgr

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"sync"
	"time"

	"github.com/Microsoft/go-winio"
	"github.com/getlantern/golog"

	lanterncore "github.com/getlantern/lantern-outline/lantern-core"
	"github.com/getlantern/lantern-outline/lantern-core/common"
	"github.com/getlantern/lantern-outline/lantern-core/utils"

	ripc "github.com/getlantern/radiance/vpn/ipc"
)

var slog = golog.LoggerFor("lantern-core.wintunsvc")

type ServiceOptions struct {
	PipeName  string
	DataDir   string
	LogDir    string
	Locale    string
	TokenPath string
}

// Service hosts the command server and manages LanternCore
// It proxies privileged commands and interacts with Radiance IPC when available
type Service struct {
	opts ServiceOptions

	core lanterncore.Core

	wtmgr *Manager

	cancel context.CancelFunc

	subsMu     sync.RWMutex
	statusSubs map[string]chan statusEvent
}

type statusEvent struct {
	Event string `json:"event"`
	State string `json:"state"`
	Ts    int64  `json:"ts"`
}

func NewService(opts ServiceOptions, wt *Manager) *Service {
	return &Service{
		opts:       opts,
		wtmgr:      wt,
		statusSubs: make(map[string]chan statusEvent),
	}
}

func (s *Service) InitCore() error {
	core, err := lanterncore.New(&utils.Opts{
		LogDir:   s.opts.LogDir,
		DataDir:  s.opts.DataDir,
		Locale:   s.opts.Locale,
		LogLevel: "debug",
	})
	if err != nil {
		slog.Errorf("Service.InitCore error err=%v", err)
		return fmt.Errorf("init LanternCore: %w", err)
	}
	s.core = core
	slog.Debugf("Service.InitCore ok")
	return nil
}

func (s *Service) statusSnapshot() statusEvent {
	return statusEvent{
		Event: "Status",
		State: s.connectionState(),
		Ts:    time.Now().Unix(),
	}
}

func (s *Service) connectionState() string {
	// ok, _ := s.core.IsVPNRunning()
	// state := map[bool]string{true: "Connected", false: "Disconnected"}[ok]
	// return state
	state, _ := ripc.GetStatus()
	if state == ripc.StatusRunning {
		return "Connected"
	}
	return "Disconnected"
}

func (s *Service) broadcastStatus() {
	evt := s.statusSnapshot()
	s.subsMu.RLock()
	for id, ch := range s.statusSubs {
		select {
		case ch <- evt:
		default:
			go func(id string) {
				s.subsMu.Lock()
				delete(s.statusSubs, id)
				s.subsMu.Unlock()
			}(id)
		}
	}
	s.subsMu.RUnlock()
}

// token file is created at install time (we also generate if missing)
func (s *Service) getToken() (string, error) {
	if _, err := os.Stat(s.opts.TokenPath); errors.Is(err, os.ErrNotExist) {
		if err := os.MkdirAll(filepath.Dir(s.opts.TokenPath), 0o755); err != nil {
			return "", err
		}
		buf := make([]byte, 32)
		if _, err := rand.Read(buf); err != nil {
			return "", err
		}
		token := base64.RawURLEncoding.EncodeToString(buf)
		if err := os.WriteFile(s.opts.TokenPath, []byte(token), 0o600); err != nil {
			return "", err
		}
		return token, nil
	}
	b, err := os.ReadFile(s.opts.TokenPath)
	return strings.TrimSpace(string(b)), err
}

func (s *Service) Start(ctx context.Context) error {
	var err error
	defer recoverErr("Service.Start", &err)

	if err = s.InitCore(); err != nil {
		return err
	}
	if s.opts.PipeName == "" {
		s.opts.PipeName = `\\.\pipe\LanternService`
	}
	if s.opts.TokenPath == "" {
		progData := os.Getenv("ProgramData")
		if progData == "" {
			progData = `C:\ProgramData`
		}
		s.opts.TokenPath = filepath.Join(progData, "Lantern", "ipc-token")
	}

	slog.Debugf("Service.Start pipe=%q datadir=%q logdir=%q token_path=%q",
		s.opts.PipeName, s.opts.DataDir, s.opts.LogDir, s.opts.TokenPath)

	token, err := s.getToken()
	if err != nil {
		return fmt.Errorf("token: %w", err)
	}

	ctx, s.cancel = context.WithCancel(ctx)

	cfg := &winio.PipeConfig{
		SecurityDescriptor: `D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;AU)`,
		MessageMode:        true,
		InputBufferSize:    128 * 1024,
		OutputBufferSize:   128 * 1024,
	}
	ln, err := winio.ListenPipe(s.opts.PipeName, cfg)
	if err != nil {
		return err
	}
	slog.Debugf("Service listening on pipe %s", s.opts.PipeName)

	go func() {
		<-ctx.Done()
		_ = ln.Close()
		slog.Debugf("Service listener closed pipe=%q", s.opts.PipeName)
	}()

	for {
		conn, err := ln.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			continue
		}
		connID := randID("c_", 6)
		slog.Debugf("Service accept conn_id=%s", connID)
		go s.handleConn(ctx, conn, token, connID)
	}
}

func (s *Service) handleWatchStatus(ctx context.Context, connID string, enc *json.Encoder, done chan struct{}) {
	ch := make(chan statusEvent, 8)
	s.subsMu.Lock()
	s.statusSubs[connID] = ch
	s.subsMu.Unlock()
	enc.Encode(s.statusSnapshot())

	go func() {
		defer func() {
			s.subsMu.Lock()
			delete(s.statusSubs, connID)
			s.subsMu.Unlock()
		}()
		prev := ""
		t := time.NewTicker(800 * time.Millisecond)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-done:
				return
			case <-t.C:
				state := s.connectionState()
				if state != prev {
					prev = state
					_ = enc.Encode(statusEvent{Event: "Status", State: state, Ts: time.Now().Unix()})
				}
			}
		}
	}()
}

func (s *Service) handleConn(ctx context.Context, c net.Conn, token, connID string) {
	dec := json.NewDecoder(c)
	enc := json.NewEncoder(c)

	done := make(chan struct{})
	defer func() {
		close(done)
		_ = c.Close()
		slog.Debugf("conn closed conn_id=%s", connID)
	}()

	for {
		var req Request
		if err := dec.Decode(&req); err != nil {
			if !errors.Is(err, io.EOF) {
				slog.Debugf("decode: %v", err)
			}
			return
		}
		reqID := req.ID
		cmd := string(req.Cmd)

		if req.Token != token {
			_ = enc.Encode(rpcErr(req.ID, "unauthorized", "bad token"))
			continue
		}
		if req.Cmd == common.CmdWatchStatus {
			s.handleWatchStatus(ctx, connID, enc, done)
			continue
		}
		start := time.Now()
		resp := s.dispatch(ctx, &req)
		elapsed := sinceMs(start)
		if resp.Error != nil {
			slog.Errorf("cmd error conn_id=%s req_id=%s cmd=%s elapsed_ms=%d code=%s msg=%s",
				connID, reqID, cmd, elapsed, resp.Error.Code, resp.Error.Message)
		} else {
			slog.Debugf("cmd ok conn_id=%s req_id=%s cmd=%s elapsed_ms=%d", connID, reqID, cmd, elapsed)
		}
		_ = enc.Encode(resp)
	}
}

func (s *Service) setupAdapter(ctx context.Context) error {
	if s.wtmgr == nil {
		return nil
	}
	ad, err := s.wtmgr.OpenOrCreateTunAdapter(ctx)
	if err != nil {
		return err
	}
	return ad.Close()
}

// checkIPCUp checks if the Radiance IPC server is available
func (s *Service) checkIPCUp(timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for time.Now().Before(deadline) {
		if _, err := ripc.GetStatus(); err == nil {
			return nil
		} else {
			lastErr = err
		}
		time.Sleep(200 * time.Millisecond)
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("radiance IPC not reachable")
	}
	return lastErr
}

// checkIPCUpOrStart: checks if IPC is down, otherwise starts via LanternCore (which brings up libbox+IPC)
func (s *Service) checkIPCUpOrStart(ctx context.Context, group string) error {
	if err := s.checkIPCUp(600 * time.Millisecond); err == nil {
		return nil
	}

	if err := s.setupAdapter(ctx); err != nil {
		return fmt.Errorf("adapter: %w", err)
	}

	// start the tunnel via core
	if group == "" {
		group = "lantern"
	}
	if err := s.core.StartTunnel(group); err != nil {
		return fmt.Errorf("start tunnel: %w", err)
	}

	if err := s.checkIPCUp(5 * time.Second); err != nil {
		return err
	}
	return nil
}

func (s *Service) dispatch(ctx context.Context, r *Request) *Response {
	defer func() {
		if rec := recover(); rec != nil {
			slog.Errorf("panic in dispatch cmd=%s: %v\n%s", r.Cmd, rec, debug.Stack())
		}
	}()

	switch r.Cmd {

	case common.CmdSetupAdapter:
		if err := s.setupAdapter(ctx); err != nil {
			return rpcErr(r.ID, "adapter_error", err.Error())
		}
		return &Response{ID: r.ID, Result: map[string]any{"ok": true}}

	case common.CmdStartTunnel:
		if err := s.checkIPCUpOrStart(ctx, "lantern"); err != nil {
			return rpcErr(r.ID, "start_error", err.Error())
		}
		if err := s.core.StartTunnel("lantern"); err != nil {
			return rpcErr(r.ID, "start_error", err.Error())
		}
		go s.broadcastStatus()
		return &Response{ID: r.ID, Result: map[string]any{"started": true}}

	case common.CmdStopTunnel:
		if err := s.core.StopTunnel(); err != nil {
			return rpcErr(r.ID, "stop_error", err.Error())
		}
		go s.broadcastStatus()
		return &Response{ID: r.ID, Result: map[string]any{"stopped": true}}

	case common.CmdIsVPNRunning:
		st, err := ripc.GetStatus()
		if err != nil {
			return rpcErr(r.ID, "status_error", err.Error())
		}
		return &Response{ID: r.ID, Result: map[string]any{"running": st == ripc.StatusRunning}}

	case common.CmdConnectToServer:
		var p struct {
			Location string `json:"location"`
			Tag      string `json:"tag"`
		}
		if err := json.Unmarshal(r.Params, &p); err != nil {
			return rpcErr(r.ID, "bad_params", err.Error())
		}
		if err := s.setupAdapter(ctx); err != nil {
			return rpcErr(r.ID, "adapter_error", err.Error())
		}
		loc := strings.TrimSpace(p.Location)
		if loc == "" {
			loc = "lantern"
		}
		if err := s.checkIPCUpOrStart(ctx, loc); err != nil {
			return rpcErr(r.ID, "connect_error", err.Error())
		}
		var err error
		if p.Tag == "" {
			err = s.core.StartTunnel(loc)
		} else {
			err = s.core.ConnectToServer(loc, p.Tag)
		}
		if err != nil {
			return rpcErr(r.ID, "connect_error", err.Error())
		}
		go s.broadcastStatus()
		return &Response{ID: r.ID, Result: "ok"}

	case common.CmdAddSplitTunnelItem, common.CmdRemoveSplitTunnelItem:
		var p struct {
			Filter string `json:"filterType"`
			Value  string `json:"value"`
		}
		if err := json.Unmarshal(r.Params, &p); err != nil {
			return rpcErr(r.ID, "bad_params", err.Error())
		}
		var err error
		if r.Cmd == common.CmdAddSplitTunnelItem {
			err = s.core.AddSplitTunnelItem(p.Filter, p.Value)
		} else {
			err = s.core.RemoveSplitTunnelItem(p.Filter, p.Value)
		}
		if err != nil {
			return rpcErr(r.ID, "split_tunnel_error", err.Error())
		}
		return &Response{ID: r.ID, Result: "ok"}

	case common.CmdGetUserData:
		b, err := s.core.UserData()
		if err != nil {
			return rpcErr(r.ID, "user_data_error", err.Error())
		}
		return &Response{ID: r.ID, Result: base64.StdEncoding.EncodeToString(b)}

	case common.CmdFetchUserData:
		b, err := s.core.FetchUserData()
		if err != nil {
			return rpcErr(r.ID, "fetch_user_data_error", err.Error())
		}
		return &Response{ID: r.ID, Result: base64.StdEncoding.EncodeToString(b)}

	default:
		return rpcErr(r.ID, "unknown_cmd", string(r.Cmd))
	}
}
