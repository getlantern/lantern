//go:build linux

package linuxsvc

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

	"github.com/getlantern/lantern-outline/lantern-core/common"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
	"github.com/getlantern/radiance/events"
	"github.com/getlantern/radiance/vpn/ipc"
)

// TODO Move to common package
type Request struct {
	ID     string          `json:"id"`
	Cmd    common.Command  `json:"cmd"`
	Params json.RawMessage `json:"params,omitempty"`
	Token  string          `json:"token,omitempty"`
}

type Response struct {
	ID     string      `json:"id"`
	Result interface{} `json:"result,omitempty"`
	Error  *RPCError   `json:"error,omitempty"`
}

type RPCError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func rpcErr(id, code, msg string) *Response {
	return &Response{ID: id, Error: &RPCError{Code: code, Message: msg}}
}

type ServiceOptions struct {
	SocketPath string
	DataDir    string
	LogDir     string
	Locale     string
	// TokenPath is where we persist a random shared secret used to authenticate clients
	TokenPath string
}

type Service struct {
	opts   ServiceOptions
	cancel context.CancelFunc
}

func NewService(opts ServiceOptions) *Service {
	return &Service{opts: opts}
}

// ---- helpers

type concurrentEncoder struct {
	mu  sync.Mutex
	enc *json.Encoder
}

func (ce *concurrentEncoder) Encode(v any) error {
	ce.mu.Lock()
	defer ce.mu.Unlock()
	return ce.enc.Encode(v)
}

// randID generates short-ish IDs for logging/tracing
func randID(prefix string, n int) string {
	if n <= 0 {
		n = 8
	}
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return prefix + base64.RawURLEncoding.EncodeToString(b)
}

func recoverErr(where string, perr *error) {
	if r := recover(); r != nil {
		slog.Error("panic", "where", where, "error", r, "stack", string(debug.Stack()))
		if perr != nil && *perr == nil {
			*perr = fmt.Errorf("panic in %s: %v", where, r)
		}
	}
}

// getToken loads the IPC token from disk, creating it if needed
// Notes:
// - Token is stored 0600 so only the owning user (or root/system service user) can read it
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

	if s.opts.SocketPath == "" {
		// Prefer XDG runtime when available (per-user), else system-wide
		if xdg := os.Getenv("XDG_RUNTIME_DIR"); xdg != "" {
			s.opts.SocketPath = filepath.Join(xdg, "lantern", "service.sock")
		} else {
			s.opts.SocketPath = "/run/lantern/service.sock"
		}
	}
	if s.opts.TokenPath == "" {
		// System-wide token path
		s.opts.TokenPath = "/var/lib/lantern/ipc-token"
	}
	if s.opts.LogDir == "" {
		s.opts.LogDir = "/var/log/lantern"
	}
	if s.opts.DataDir == "" {
		s.opts.DataDir = "/var/lib/lantern"
	}

	slog.Info("Starting Lantern",
		"socket", s.opts.SocketPath,
		"data_dir", s.opts.DataDir,
		"log_dir", s.opts.LogDir,
		"token_path", s.opts.TokenPath,
	)

	token, err := s.getToken()
	if err != nil {
		return fmt.Errorf("token: %w", err)
	}

	if err := os.MkdirAll(filepath.Dir(s.opts.SocketPath), 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(s.opts.LogDir, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(s.opts.DataDir, 0o755); err != nil {
		return err
	}

	if _, statErr := os.Stat(s.opts.SocketPath); statErr == nil {
		_ = os.Remove(s.opts.SocketPath)
	}

	ln, err := net.Listen("unix", s.opts.SocketPath)
	if err != nil {
		return err
	}
	_ = os.Chmod(s.opts.SocketPath, 0o660)

	ctx, s.cancel = context.WithCancel(ctx)
	go func() {
		<-ctx.Done()
		_ = ln.Close()
		_ = os.Remove(s.opts.SocketPath)
	}()

	for {
		c, err := ln.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			continue
		}
		connID := randID("c_", 6)
		slog.Debug("accept", "conn_id", connID)
		go s.handleConn(ctx, c, token, connID)
	}
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

func (s *Service) handleWatchStatus(ctx context.Context, enc *concurrentEncoder) {
	sub := events.Subscribe(func(evt ipc.StatusUpdateEvent) {
		se := statusEvent{Event: "Status", State: evt.Status.String(), Ts: time.Now().Unix()}
		if evt.Error != nil {
			se.Error = evt.Error.Error()
		}
		_ = enc.Encode(se)
	})
	go func() {
		<-ctx.Done()
		events.Unsubscribe(sub)
	}()
}

// This is a very lightweight "tail -f" implementation
// It's intentionally dumb-but-portable: no inotify dependency, just polling
// TODO: switch to fsnotify/inotify
func (s *Service) handleWatchLogs(ctx context.Context, enc *concurrentEncoder, done <-chan struct{}) {
	logFile := filepath.Join(s.opts.LogDir, "lantern.log")
	_ = os.MkdirAll(s.opts.LogDir, 0o755)
	if _, err := os.Stat(logFile); errors.Is(err, os.ErrNotExist) {
		_ = os.WriteFile(logFile, nil, 0o644)
	}

	// On subscribe, send a small backlog so the UI has context
	const maxTail = 200
	if last, err := readLastLines(logFile, maxTail); err == nil && len(last) > 0 {
		_ = enc.Encode(logsEvent{Event: "Logs", Lines: last, Ts: time.Now().Unix()})
	}

	go func() {
		var f *os.File
		var off int64

		// open (and optionally reset) the file and seek to the right offset
		open := func(reset bool) {
			if f != nil {
				_ = f.Close()
			}
			ff, err := os.Open(logFile)
			if err != nil {
				return
			}
			f = ff
			fi, _ := f.Stat()
			if reset || fi == nil {
				off = 0
			} else {
				off = fi.Size()
			}
			_, _ = f.Seek(off, io.SeekStart)
		}

		open(false)
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
					open(true)
					continue
				}
				if fi.Size() < off {
					open(true)
					continue
				}
				if fi.Size() == off {
					continue
				}

				// Read only the delta since last tick
				n := fi.Size() - off
				buf := make([]byte, n)
				_, err = io.ReadFull(f, buf)
				if err != nil {
					open(false)
					continue
				}
				off = fi.Size()

				// Split into lines, drop empty trailing fragments
				raw := strings.Split(string(buf), "\n")
				var lines []string
				for _, ln := range raw {
					if ln != "" {
						lines = append(lines, ln)
					}
				}
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
				slog.Debug("decode error", "conn_id", connID, "err", err)
			}
			return
		}

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
		elapsed := time.Since(start).Milliseconds()
		if resp.Error != nil {
			slog.Error("cmd error", "conn_id", connID, "req_id", req.ID, "cmd", req.Cmd, "elapsed_ms", elapsed,
				"code", resp.Error.Code, "msg", resp.Error.Message)
		} else {
			slog.Debug("cmd ok", "conn_id", connID, "req_id", req.ID, "cmd", req.Cmd, "elapsed_ms", elapsed)
		}
		_ = enc.Encode(resp)
	}
}

func (s *Service) dispatch(ctx context.Context, r *Request) *Response {
	defer func() {
		if rec := recover(); rec != nil {
			slog.Error("panic in dispatch", "cmd", r.Cmd, "error", rec, "stack", string(debug.Stack()))
		}
	}()

	switch r.Cmd {

	case common.CmdStartTunnel:
		go func() {
			events.Emit(ipc.StatusUpdateEvent{Status: ipc.Connecting})
			if err := vpn_tunnel.StartVPN(nil, &utils.Opts{
				DataDir:  s.opts.DataDir,
				Locale:   s.opts.Locale,
				LogDir:   s.opts.LogDir,
				LogLevel: "trace",
				Deviceid: "",
				// TelemetryConsent: TODO add this
			}); err != nil {
				slog.Error("StartVPN failed", "err", err)
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.ErrorStatus, Error: err})
			} else {
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.Connected})
			}
		}()
		return &Response{ID: r.ID, Result: map[string]any{"started": true}}

	case common.CmdStopTunnel:
		go func() {
			events.Emit(ipc.StatusUpdateEvent{Status: ipc.Disconnecting})
			if err := vpn_tunnel.StopVPN(); err != nil {
				slog.Error("StopVPN failed", "err", err)
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.ErrorStatus, Error: err})
			} else {
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.Disconnected})
			}
		}()
		return &Response{ID: r.ID, Result: map[string]any{"stopped": true}}

	case common.CmdIsVPNRunning:
		running := vpn_tunnel.IsVPNRunning()
		go func() {
			if running {
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.Connected})
			} else {
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.Disconnected})
			}
		}()
		return &Response{ID: r.ID, Result: map[string]any{"running": running}}

	case common.CmdConnectToServer:
		var p struct {
			Location string `json:"location"`
			Tag      string `json:"tag"`
		}
		if err := json.Unmarshal(r.Params, &p); err != nil {
			return rpcErr(r.ID, "bad_params", err.Error())
		}
		group := strings.TrimSpace(p.Location)
		tag := strings.TrimSpace(p.Tag)

		go func() {
			events.Emit(ipc.StatusUpdateEvent{Status: ipc.Connecting})
			if err := vpn_tunnel.ConnectToServer(group, tag, nil, &utils.Opts{
				DataDir:  s.opts.DataDir,
				Locale:   s.opts.Locale,
				LogDir:   s.opts.LogDir,
				LogLevel: "trace",
			}); err != nil {
				slog.Error("ConnectToServer failed", "err", err)
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.ErrorStatus, Error: err})
			} else {
				events.Emit(ipc.StatusUpdateEvent{Status: ipc.Connected})
			}
		}()

		return &Response{ID: r.ID, Result: "ok"}

	default:
		return rpcErr(r.ID, "unknown_cmd", string(r.Cmd))
	}
}

// readLastLines reads the last lines of the log file
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
