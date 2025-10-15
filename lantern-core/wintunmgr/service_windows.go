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

	rvpn "github.com/getlantern/radiance/vpn"
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

type logsEvent struct {
	Event string   `json:"event"`
	Lines []string `json:"lines"`
	Ts    int64    `json:"ts"`
}

func NewService(opts ServiceOptions, wt *Manager) *Service {
	return &Service{
		opts:       opts,
		wtmgr:      wt,
		statusSubs: make(map[string]chan statusEvent),
	}
}

func (s *Service) vpnOpts() *utils.Opts {
	return &utils.Opts{
		Locale:   s.opts.Locale,
		DataDir:  s.opts.DataDir,
		LogDir:   s.opts.LogDir,
		LogLevel: lanterncore.DefaultLogLevel,
	}
}

// / Flutter event emitter implementation for Windows
type windowsFlutterEventEmitter struct{}

func (e *windowsFlutterEventEmitter) SendEvent(event *utils.FlutterEvent) {
	// todo implement windows flutter event emitter
	// send back to flutter via IPC or other means

}

func (s *Service) InitCore() error {
	core, err := lanterncore.New(&utils.Opts{
		Locale:   s.opts.Locale,
		LogLevel: lanterncore.DefaultLogLevel,
	}, &windowsFlutterEventEmitter{})
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
	state, _ := ripc.GetStatus(context.Background())
	if state == ripc.StatusRunning {
		return "Connected"
	}
	return "Disconnected"
}

func (s *Service) broadcastStatus() {
	evt := s.statusSnapshot()
	s.subsMu.RLock()
	defer s.subsMu.RUnlock()
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

	// Start the Radiance IPC control plane
	if err := rvpn.InitIPC("", nil); err != nil {
		return fmt.Errorf("init radiance IPC: %w", err)
	}

	ctx, s.cancel = context.WithCancel(ctx)

	cfg := &winio.PipeConfig{
		SecurityDescriptor: `D:P` +
			`(A;;GA;;;SY)` +
			`(A;;GRGW;;;IU)` +
			`(A;;GRGW;;;BA)` +
			`(A;;GRGW;;;S-1-15-2-1)` +
			`(A;;GRGW;;;S-1-15-2-2)`,
		MessageMode:      true,
		InputBufferSize:  128 * 1024,
		OutputBufferSize: 128 * 1024,
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

type connWriter struct {
	enc *json.Encoder
	mu  sync.Mutex
}

func (w *connWriter) Send(v any) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.enc.Encode(v)
}

func (s *Service) handleWatchStatus(ctx context.Context, connID string, w *connWriter, done <-chan struct{}, closeDone func()) {
	ch := make(chan statusEvent, 8)
	s.subsMu.Lock()
	s.statusSubs[connID] = ch
	s.subsMu.Unlock()

	first := s.statusSnapshot()
	if err := w.Send(first); err != nil {
		slog.Debugf("status write error (initial) conn_id=%s: %v", connID, err)
		closeDone()
		return
	}
	prev := first.State

	go func() {
		defer func() {
			s.subsMu.Lock()
			delete(s.statusSubs, connID)
			s.subsMu.Unlock()
		}()
		t := time.NewTicker(800 * time.Millisecond)
		defer t.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-done:
				return
			case evt := <-ch:
				if err := w.Send(evt); err != nil {
					slog.Debugf("status write error (broadcast) conn_id=%s: %v", connID, err)
					closeDone()
					return
				}
				prev = evt.State
			case <-t.C:
				state := s.connectionState()
				if state != prev {
					prev = state
					if err := w.Send(statusEvent{Event: "Status", State: state, Ts: time.Now().Unix()}); err != nil {
						slog.Debugf("status write error (tick) conn_id=%s: %v", connID, err)
						closeDone()
						return
					}
				}
			}
		}
	}()
}

func (s *Service) handleWatchLogs(ctx context.Context, connID string, w *connWriter, done <-chan struct{}, closeDone func()) {
	logFile := filepath.Join(s.opts.LogDir, "lantern.log")
	_ = os.MkdirAll(s.opts.LogDir, 0o755)
	if _, err := os.Stat(logFile); errors.Is(err, os.ErrNotExist) {
		_ = os.WriteFile(logFile, nil, 0o644)
	}

	// Send recent tail
	const maxTail = 200
	if last, err := readLastLines(logFile, maxTail); err == nil && len(last) > 0 {
		if err := w.Send(logsEvent{Event: "Logs", Lines: last, Ts: time.Now().Unix()}); err != nil {
			slog.Debugf("logs write error (tail) conn_id=%s: %v", connID, err)
			closeDone()
			return
		}
	}

	go func() {
		var f *os.File
		var err error
		var off int64 = 0

		open := func(reset bool) error {
			if f != nil {
				_ = f.Close()
			}
			f, err = os.Open(logFile)
			if err != nil {
				return err
			}
			fi, _ := f.Stat()
			if reset || fi == nil {
				off = 0
			} else {
				off = fi.Size()
			}
			_, _ = f.Seek(off, io.SeekStart)
			return nil
		}

		_ = open(false)
		defer func() {
			if f != nil {
				_ = f.Close()
			}
		}()

		ticker := time.NewTicker(600 * time.Millisecond)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-done:
				return
			case <-ticker.C:
				fi, err := os.Stat(logFile)
				if err != nil {
					_ = open(true)
					continue
				}
				if fi.Size() < off {
					_ = open(true)
					continue
				}
				if fi.Size() == off {
					continue
				}
				n := fi.Size() - off
				buf := make([]byte, n)
				_, err = io.ReadFull(f, buf)
				if err != nil {
					_ = open(false)
					continue
				}
				off = fi.Size()

				raw := strings.Split(string(buf), "\n")
				var lines []string
				for _, ln := range raw {
					if ln == "" {
						continue
					}
					lines = append(lines, ln)
				}
				// Send new lines to client
				if len(lines) > 0 {
					if err := w.Send(logsEvent{Event: "Logs", Lines: lines, Ts: time.Now().Unix()}); err != nil {
						slog.Debugf("logs write error (stream) conn_id=%s: %v", connID, err)
						closeDone()
						return
					}
				}
			}
		}
	}()
}

func (s *Service) handleConn(ctx context.Context, c net.Conn, token, connID string) {
	dec := json.NewDecoder(c)
	w := &connWriter{enc: json.NewEncoder(c)}

	done := make(chan struct{})
	var doneOnce sync.Once
	closeDone := func() { doneOnce.Do(func() { close(done) }) }

	defer func() {
		closeDone()
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
			_ = w.Send(rpcErr(req.ID, "unauthorized", "bad token"))
			continue
		}

		switch req.Cmd {
		case common.CmdWatchStatus:
			s.handleWatchStatus(ctx, connID, w, done, closeDone)
			continue
		case common.CmdWatchLogs:
			s.handleWatchLogs(ctx, connID, w, done, closeDone)
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
		if err := w.Send(resp); err != nil {
			slog.Debugf("encode error conn_id=%s: %v", connID, err)
			return
		}
	}
}

// ---- Adapter / IPC helpers ----
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

func (s *Service) checkIPCUp(ctx context.Context, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for time.Now().Before(deadline) {
		if _, err := ripc.GetStatus(ctx); err == nil {
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
		if err := ripc.StartService(ctx, "lantern", ""); err != nil {
			return rpcErr(r.ID, "start_error", err.Error())
		}
		go s.broadcastStatus()
		return &Response{ID: r.ID, Result: map[string]any{"started": true}}

	case common.CmdStopTunnel:
		if err := ripc.StopService(ctx); err != nil {
			return rpcErr(r.ID, "stop_error", err.Error())
		}
		go s.broadcastStatus()
		return &Response{ID: r.ID, Result: map[string]any{"stopped": true}}

	case common.CmdIsVPNRunning:
		st, err := ripc.GetStatus(ctx)
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
		group := strings.TrimSpace(p.Location)
		if group == "" {
			group = "lantern"
		}
		if err := ripc.StartService(ctx, group, p.Tag); err != nil {
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

	default:
		return rpcErr(r.ID, "unknown_cmd", string(r.Cmd))
	}
}

func readLastLines(path string, max int) ([]string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(b) > 64*1024 {
		b = b[len(b)-64*1024:]
	}
	lines := strings.Split(string(b), "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	if len(lines) > max {
		lines = lines[len(lines)-max:]
	}
	return lines, nil
}
