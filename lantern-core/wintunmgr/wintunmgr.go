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
	"sync"
	"time"

	"github.com/Microsoft/go-winio"
	"github.com/getlantern/golog"
	lanterncore "github.com/getlantern/lantern-outline/lantern-core"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
	"github.com/sagernet/gvisor/pkg/log"
	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wintun"
)

var (
	slog = golog.LoggerFor("lantern-core.wintunsvc")
)

// Manager owns Wintun adapter lifecycle for a given name/pool
type Manager struct {
	AdapterName string
	PoolName    string
	// deterministic GUID for stable NLA entries
	GUID *windows.GUID
}

// New returns a new Manager with some defaults
func New(adapterName, poolName string, guid *windows.GUID) *Manager {
	if adapterName == "" {
		adapterName = "Lantern"
	}
	if poolName == "" {
		poolName = adapterName
	}
	return &Manager{
		AdapterName: adapterName,
		PoolName:    poolName,
		GUID:        guid,
	}
}

// OpenOrCreateTunAdapter opens an existing adapter or creates it if missing
func (m *Manager) OpenOrCreateTunAdapter(ctx context.Context) (*wintun.Adapter, error) {
	if v, _ := wintun.RunningVersion(); v != 0 {
		log.Debugf("Wintun running version: %d", v)
	}

	if ad, err := wintun.OpenAdapter(m.AdapterName); err == nil {
		log.Debugf("Opened existing Wintun adapter %q", m.AdapterName)
		return ad, nil
	}

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}

	// installs the driver on first use
	ad, err := wintun.CreateAdapter(m.AdapterName, m.PoolName, m.GUID)
	if err != nil {
		return nil, fmt.Errorf("create Wintun adapter %q: %w", m.AdapterName, err)
	}
	log.Debugf("Created Wintun adapter %q (pool=%q)", m.AdapterName, m.PoolName)
	return ad, nil
}

// Open tries opening the adapter by name
func (m *Manager) Open() (*wintun.Adapter, error) {
	ad, err := wintun.OpenAdapter(m.AdapterName)
	if err != nil {
		return nil, fmt.Errorf("open Wintun adapter %q: %w", m.AdapterName, err)
	}
	return ad, nil
}

// Create forces creation (installs driver on first use)
func (m *Manager) Create() (*wintun.Adapter, error) {
	// requires elevation
	ad, err := wintun.CreateAdapter(m.AdapterName, m.PoolName, m.GUID)
	if err != nil {
		return nil, fmt.Errorf("create Wintun adapter %q: %w", m.AdapterName, err)
	}
	return ad, nil
}

// UninstallDriver attempts to remove the Wintun driver
func (m *Manager) UninstallDriver() error {
	if err := wintun.Uninstall(); err != nil {
		return fmt.Errorf("wintun uninstall: %w", err)
	}
	return nil
}

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

	cancel context.CancelFunc
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
		return fmt.Errorf("init LanternCore: %w", err)
	}
	s.core = core
	return nil
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
	if err := s.InitCore(); err != nil {
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
	slog.Debugf("listening on pipe %s", s.opts.PipeName)

	go func() {
		<-ctx.Done()
		_ = ln.Close()
	}()

	for {
		conn, err := ln.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			continue
		}
		go s.handleConn(ctx, conn, token)
	}
}

func (s *Service) handleConn(ctx context.Context, c net.Conn, token string) {
	defer c.Close()

	dec := json.NewDecoder(c)
	enc := json.NewEncoder(c)

	for {
		var req Request
		if err := dec.Decode(&req); err != nil {
			if !errors.Is(err, io.EOF) {
				slog.Debugf("decode: %v", err)
			}
			return
		}
		if req.Token != token {
			_ = enc.Encode(rpcErr(req.ID, "unauthorized", "bad token"))
			continue
		}
		resp := s.dispatch(ctx, &req)
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

func (s *Service) dispatch(ctx context.Context, r *Request) *Response {
	switch r.Cmd {
	case CmdSetupAdapter:
		if _, err := s.wtmgr.OpenOrCreateTunAdapter(ctx); err != nil {
			return rpcErr(r.ID, "adapter_error", err.Error())
		}
		return &Response{ID: r.ID, Result: map[string]any{"ok": true}}
	case CmdStartTunnel:
		// Make sure adapter exists first
		if err := s.setupAdapter(ctx); err != nil {
			return rpcErr(r.ID, "adapter_error", err.Error())
		}
		// runs Radiance (vpn_tunnel) inside the service
		if err := vpn_tunnel.StartVPN(nil, &utils.Opts{
			DataDir: s.opts.DataDir, Locale: s.opts.Locale,
		}); err != nil {
			return rpcErr(r.ID, "start_error", err.Error())
		}
		s.mu.Lock()
		s.running = true
		s.mu.Unlock()
		return &Response{ID: r.ID, Result: map[string]any{"started": true}}

	case CmdStopTunnel:
		if err := vpn_tunnel.StopVPN(); err != nil {
			return rpcErr(r.ID, "stop_error", err.Error())
		}
		s.mu.Lock()
		s.running = false
		s.mu.Unlock()
		return &Response{ID: r.ID, Result: map[string]any{"stopped": true}}
	case CmdIsVPNRunning:
		return &Response{ID: r.ID, Result: map[string]any{"running": vpn_tunnel.IsVPNRunning()}}
	case CmdStatus:
		s.mu.RLock()
		running := s.running
		s.mu.RUnlock()
		return &Response{ID: r.ID, Result: map[string]any{
			"state": map[bool]string{true: "connected", false: "disconnected"}[running],
			"ts":    time.Now().Unix(),
		}}
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
