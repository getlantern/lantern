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
	"log/slog"
	"net"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"sync"
	"time"

	"github.com/Microsoft/go-winio"
	"github.com/getlantern/lantern-outline/lantern-core/common"
	"github.com/getlantern/radiance/events"
	"github.com/getlantern/radiance/servers"
	rvpn "github.com/getlantern/radiance/vpn"
	"github.com/getlantern/radiance/vpn/ipc"
	ripc "github.com/getlantern/radiance/vpn/ipc"
)

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
	opts    ServiceOptions
	wtmgr   *Manager
	cancel  context.CancelFunc
	rServer *ripc.Server
}

type statusEvent struct {
	Event string `json:"event"`
	State string `json:"state"`
	Ts    int64  `json:"ts"`
	Error string `json:"error,omitempty"`
}

type logsEvent struct {
	Event string   `json:"event"`
	Lines []string `json:"lines"`
	Ts    int64    `json:"ts"`
}

// concurrentEncoder ensures that multiple goroutines can safely write JSON responses to the
// IPC stream sequentially without colliding and corrupting the data.
type concurrentEncoder struct {
	mu  sync.Mutex
	enc *json.Encoder
}

func (ce *concurrentEncoder) Encode(v any) error {
	ce.mu.Lock()
	defer ce.mu.Unlock()
	return ce.enc.Encode(v)
}

func NewService(opts ServiceOptions, wt *Manager) (*Service, error) {
	// Start the Radiance IPC control plane
	server, err := rvpn.InitIPC("", nil)
	if err != nil {
		return nil, fmt.Errorf("init radiance IPC: %w", err)
	}
	return &Service{
		opts:    opts,
		wtmgr:   wt,
		rServer: server,
	}, nil
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

	slog.Info("Starting Windows service", "pipe", s.opts.PipeName, "data_dir",
		s.opts.DataDir, "log_dir", s.opts.LogDir, "token_path", s.opts.TokenPath)

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
	slog.Debug("Service listening on pipe", "pipe", s.opts.PipeName)

	go func() {
		<-ctx.Done()
		_ = ln.Close()
		slog.Debug("Service listener closed pipe", "pipe", s.opts.PipeName)
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
		slog.Debug("Service accept", "conn_id", connID)
		go s.handleConn(ctx, conn, token, connID)
	}
}

func (s *Service) handleWatchStatus(ctx context.Context, enc *concurrentEncoder) {
	sub := events.Subscribe(func(evt ripc.StatusUpdateEvent) {
		slog.Debug("Sending status event", "state", evt.Status.String(), "error", evt.Error)
		if evt.Error != nil {
			enc.Encode(statusEvent{Event: "Status", State: evt.Status.String(), Ts: time.Now().Unix(), Error: evt.Error.Error()})
		} else {
			enc.Encode(statusEvent{Event: "Status", State: evt.Status.String(), Ts: time.Now().Unix()})
		}
	})

	// Unsubscribe when context is done
	go func() {
		<-ctx.Done()
		events.Unsubscribe(sub)
	}()
}

func (s *Service) handleWatchLogs(ctx context.Context, enc *concurrentEncoder, done chan struct{}) {
	logFile := filepath.Join(s.opts.LogDir, "lantern.log")
	_ = os.MkdirAll(s.opts.LogDir, 0o755)
	if _, err := os.Stat(logFile); errors.Is(err, os.ErrNotExist) {
		_ = os.WriteFile(logFile, nil, 0o644)
	}

	// Start by sending the most recent chunk of the log
	const maxTail = 200
	if last, err := readLastLines(logFile, maxTail); err == nil && len(last) > 0 {
		_ = enc.Encode(logsEvent{Event: "Logs", Lines: last, Ts: time.Now().Unix()})
	}

	// Then keep watching the file to stream new lines as they’re written
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

		// Poll for changes
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
					// Nothing new to read
					continue
				}
				// Read only new bytes that were just appended
				n := fi.Size() - off
				buf := make([]byte, n)
				_, err = io.ReadFull(f, buf)
				if err != nil {
					_ = open(false)
					continue
				}
				off = fi.Size()

				chunk := string(buf)
				raw := strings.Split(chunk, "\n")
				var lines []string
				for _, ln := range raw {
					if ln == "" {
						continue
					}
					lines = append(lines, ln)
				}
				// Send new lines to client
				if len(lines) > 0 {
					_ = enc.Encode(logsEvent{Event: "Logs", Lines: lines, Ts: time.Now().Unix()})
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
		slog.Debug("conn closed", "conn_id", connID)
	}()

	for {
		var req Request
		if err := dec.Decode(&req); err != nil {
			if !errors.Is(err, io.EOF) {
				slog.Debug("decode error", "error", err)
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
			s.handleWatchStatus(ctx, &concurrentEncoder{enc: enc})
			continue
		}
		if req.Cmd == common.CmdWatchLogs {
			s.handleWatchLogs(ctx, &concurrentEncoder{enc: enc}, done)
			continue
		}
		start := time.Now()
		resp := s.dispatch(ctx, &req)
		elapsed := sinceMs(start)
		if resp.Error != nil {
			slog.Error("cmd error", "conn_id", connID, "req_id", reqID, "cmd", cmd, "elapsed_ms", elapsed,
				"code", resp.Error.Code, "msg", resp.Error.Message)
		} else {
			slog.Debug("cmd ok", "conn_id", connID, "req_id", reqID, "cmd", cmd, "elapsed_ms", elapsed)
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

func (s *Service) dispatch(ctx context.Context, r *Request) *Response {
	defer func() {
		if rec := recover(); rec != nil {
			slog.Error("panic in dispatch", "cmd", r.Cmd, "error", rec, "stack", string(debug.Stack()))
		}
	}()

	slog.Debug("Service dispatch", "cmd", r.Cmd)
	switch r.Cmd {

	case common.CmdSetupAdapter:
		if err := s.setupAdapter(ctx); err != nil {
			return rpcErr(r.ID, "adapter_error", err.Error())
		}
		return &Response{ID: r.ID, Result: map[string]any{"ok": true}}

	case common.CmdStartTunnel:
		go func() {
			events.Emit(ipc.StatusUpdateEvent{Status: ripc.Connecting})
			if err := s.rServer.StartService(ctx, "lantern", ""); err != nil {
				slog.Error("Error starting service: %w", err)
				events.Emit(ipc.StatusUpdateEvent{Status: ripc.ErrorStatus, Error: err})
			}
		}()
		return &Response{ID: r.ID, Result: map[string]any{"started": true}}

	case common.CmdStopTunnel:
		go func() {
			events.Emit(ipc.StatusUpdateEvent{Status: ripc.Disconnecting})
			if err := s.rServer.StopService(ctx); err != nil {
				slog.Error("Error stopping service: %w", err)
				events.Emit(ipc.StatusUpdateEvent{Status: ripc.ErrorStatus, Error: err})
			}
		}()
		return &Response{ID: r.ID, Result: map[string]any{"stopped": true}}

	case common.CmdIsVPNRunning:
		st := s.rServer.GetStatus()
		go func() {
			if st == ripc.StatusRunning {
				events.Emit(ipc.StatusUpdateEvent{Status: ripc.Connected})
			} else {
				events.Emit(ipc.StatusUpdateEvent{Status: ripc.Disconnected})
			}
		}()
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
		switch group {
		case "privateServer":
			group = servers.SGUser
		case "lanternLocation":
			group = servers.SGLantern
		}
		go func(group, tag string) {
			events.Emit(ipc.StatusUpdateEvent{Status: ripc.Connecting})
			if err := s.rServer.StartService(ctx, group, p.Tag); err != nil {
				slog.Error("Error connecting to server: %w", err)
				events.Emit(ipc.StatusUpdateEvent{Status: ripc.ErrorStatus, Error: err})
			}
		}(group, p.Tag)
		return &Response{ID: r.ID, Result: "ok"}

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
