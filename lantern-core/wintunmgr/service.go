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
	"sync"
	"time"

	"github.com/Microsoft/go-winio"
	lanterncore "github.com/getlantern/lantern-outline/lantern-core"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
)

type ServiceOptions struct {
	PipeName  string // `\\.\pipe\LanternService`
	DataDir   string
	LogDir    string
	Locale    string
	TokenPath string // %ProgramData%\Lantern\ipc-token
}

// Service hosts the command server and owns LanternCore/Wintun manager state
type Service struct {
	opts    ServiceOptions
	core    lanterncore.Core
	wtmgr   *Manager
	mu      sync.RWMutex
	running bool

	cancel     context.CancelFunc
	subsMu     sync.RWMutex
	statusSubs map[string]chan statusEvent
}

type statusEvent struct {
	Event string `json:"event"`
	State string `json:"state"`
	Ts    int64  `json:"ts"`
}

func NewService(opts ServiceOptions, wt *Manager) *Service {
	return &Service{opts: opts, wtmgr: wt}
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
	running := s.isRunning()
	if running {
		return "connected"
	}
	return "disconnected"
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

// token file is created at install time
func (s *Service) getToken() (string, error) {
	// generate if missing
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
	return string(b), err
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
		SecurityDescriptor: `D:P(A;;GA;;;SY)(A;;GA;;;BA)`,
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

	_ = enc.Encode(s.statusSnapshot())

	// write loop that pushes events until conn is closed
	go func() {
		for {
			select {
			case evt := <-ch:
				if err := enc.Encode(evt); err != nil {
					slog.Debugf("watch write error conn_id=%s: %v", connID, err)
					s.subsMu.Lock()
					delete(s.statusSubs, connID)
					s.subsMu.Unlock()
					return
				}
			case <-ctx.Done():
				return
			case <-done:
				return
			}
		}
	}()

}

func (s *Service) handleConn(ctx context.Context, c net.Conn, token, connID string) {

	dec := json.NewDecoder(c)
	enc := json.NewEncoder(c)

	done := make(chan struct{})

	defer func() {
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
		if req.Cmd == CmdWatchStatus {
			s.handleWatchStatus(ctx, connID, enc, done)
			return
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
	ad, err := s.wtmgr.OpenOrCreateTunAdapter(ctx)
	if err != nil {
		return err
	}
	ad.Close()
	return nil
}

func (s *Service) isRunning() bool {
	s.mu.RLock()
	running := s.running
	s.mu.RUnlock()
	return running
}

func (s *Service) setIsRunning(running bool) {
	s.mu.Lock()
	s.running = running
	s.mu.Unlock()
	s.broadcastStatus()
}

func (s *Service) dispatch(ctx context.Context, r *Request) *Response {
	defer func() {
		if rec := recover(); rec != nil {
			slog.Errorf("panic in dispatch cmd=%s: %v\n%s", r.Cmd, rec, debug.Stack())
		}
	}()

	switch r.Cmd {
	case CmdSetupAdapter:
		// if _, err := s.wtmgr.OpenOrCreateTunAdapter(ctx); err != nil {
		// 	return rpcErr(r.ID, "adapter_error", err.Error())
		// }
		return &Response{ID: r.ID, Result: map[string]any{"ok": true}}
	case CmdStartTunnel:
		// Make sure adapter exists first
		// if err := s.setupAdapter(ctx); err != nil {
		// 	return rpcErr(r.ID, "adapter_error", err.Error())
		// }
		if err := vpn_tunnel.StartVPN(nil, &utils.Opts{
			DataDir: s.opts.DataDir, Locale: s.opts.Locale,
		}); err != nil {
			return rpcErr(r.ID, "start_error", err.Error())
		}
		s.setIsRunning(true)
		return &Response{ID: r.ID, Result: map[string]any{"started": true}}

	case CmdStopTunnel:
		if err := vpn_tunnel.StopVPN(); err != nil {
			return rpcErr(r.ID, "stop_error", err.Error())
		}
		s.setIsRunning(false)
		return &Response{ID: r.ID, Result: map[string]any{"stopped": true}}
	case CmdIsVPNRunning:
		return &Response{ID: r.ID, Result: map[string]any{"running": s.isRunning()}}
	// case CmdStatus:
	// 	running := vpn_tunnel.IsVPNRunning()
	// 	status := "disconnected"
	// 	if s.isRunning() || vpn_tunnel.IsVPNRunning() {
	// 		s.setIsRunning(running)
	// 		status = "connected"
	// 	}
	// 	return &Response{ID: r.ID, Result: map[string]any{
	// 		"state": status,
	// 		"ts":    time.Now().Unix(),
	// 	}}
	case CmdConnectToServer:
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
		if err := vpn_tunnel.ConnectToServer(p.Location, p.Tag, nil, &utils.Opts{
			DataDir: s.opts.DataDir, Locale: s.opts.Locale,
		}); err != nil {
			return rpcErr(r.ID, "connect_error", err.Error())
		}
		s.setIsRunning(true)
		return &Response{ID: r.ID, Result: "ok"}

	case CmdAddSplitTunnelItem, CmdRemoveSplitTunnelItem:
		var p struct {
			Filter string `json:"filterType"`
			Value  string `json:"value"`
		}
		if err := json.Unmarshal(r.Params, &p); err != nil {
			return rpcErr(r.ID, "bad_params", err.Error())
		}
		var err error
		if r.Cmd == CmdAddSplitTunnelItem {
			err = s.core.AddSplitTunnelItem(p.Filter, p.Value)
		} else {
			err = s.core.RemoveSplitTunnelItem(p.Filter, p.Value)
		}
		if err != nil {
			return rpcErr(r.ID, "split_tunnel_error", err.Error())
		}
		return &Response{ID: r.ID, Result: "ok"}

	case CmdGetUserData:
		b, err := s.core.UserData()
		if err != nil {
			return rpcErr(r.ID, "user_data_error", err.Error())
		}
		return &Response{ID: r.ID, Result: base64.StdEncoding.EncodeToString(b)}

	case CmdFetchUserData:
		b, err := s.core.FetchUserData()
		if err != nil {
			return rpcErr(r.ID, "fetch_user_data_error", err.Error())
		}
		return &Response{ID: r.ID, Result: base64.StdEncoding.EncodeToString(b)}
	default:
		return rpcErr(r.ID, "unknown_cmd", string(r.Cmd))
	}
}
