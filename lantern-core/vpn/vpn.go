package vpn

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/config"
)

const (
	// Duration to wait before timing out a UDP session
	_udpSessionTimeout = 60 * time.Second

	configPollInterval = 1 * time.Minute
)

var (
	log = golog.LoggerFor("lantern.vpn")
)

type vpnServer struct {
	listener      net.Listener      // Network listener for accepting client connections
	mtu           int               // Maximum Transmission Unit size for the VPN tunnel
	offset        int               // Offset for packet processing
	clients       map[net.Conn]bool // Map to track active client connections
	vpnConnected  bool              // whether the VPN is currently connected
	baseDir       string
	configHandler *config.ConfigHandler // handles fetching the proxy configuration from the proxy server
	logMu         sync.Mutex
	logPort       int64
	tunnel        Tunnel // tunnel that manages packet forwarding
	tunnelStop    chan struct{}
	radiance      *radiance.Radiance // radiance instance the VPN server is configured with
	mu            sync.RWMutex
}

// Opts are the options the VPN server can be configured with
type Opts struct {
	Address       string
	BaseDir       string
	LogPort       int64
	Mtu           int
	Offset        int
	ConfigHandler *config.ConfigHandler
	Radiance      *radiance.Radiance
}

func newVPNServer(opts *Opts) *vpnServer {
	server := &vpnServer{
		baseDir:       opts.BaseDir,
		logPort:       opts.LogPort,
		mtu:           opts.Mtu,
		offset:        opts.Offset,
		radiance:      opts.Radiance,
		configHandler: opts.ConfigHandler,
		clients:       make(map[net.Conn]bool),
	}
	return server
}

// Stop stops the VPN server and closes the tunnel.
func (s *vpnServer) stop() error {
	if !s.IsVPNConnected() {
		return errors.New("VPN isn't running")
	}
	defer s.broadcastStatus()
	s.setConnected(false)

	return nil
}

// IsVPNConnected returns the current connection status of the VPN.
func (s *vpnServer) IsVPNConnected() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.vpnConnected
}

func (s *vpnServer) setConnected(isConnected bool) {
	s.mu.Lock()
	s.vpnConnected = isConnected
	s.mu.Unlock()
}

func (s *vpnServer) acceptConnections(ctx context.Context) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			log.Errorf("Failed to accept connection: %v", err)
			continue
		}
		s.mu.Lock()
		s.clients[conn] = true
		s.mu.Unlock()
		log.Debugf("Client connected: %v", conn.RemoteAddr())
	}
}

// broadcastStatus sends the current VPN status ("connected" or "disconnected")
// to all connected clients. If sending to a client fails, it logs the error,
// closes the connection, and removes the client from the clients map.
func (s *vpnServer) broadcastStatus() {
	s.mu.RLock()
	defer s.mu.RUnlock()

	status := "disconnected"
	if s.IsVPNConnected() {
		status = "connected"
	}

	message := fmt.Sprintf("VPN is %s\n", status)

	for conn := range s.clients {
		_, err := conn.Write([]byte(message))
		if err != nil {
			log.Errorf("Failed to send to %v: %v", conn.RemoteAddr(), err)
			conn.Close()
			delete(s.clients, conn)
		}
	}
}
