package vpn

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net"
	"sync"
	"time"

	localconfig "github.com/getlantern/lantern-outline/config"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/config"
)

const (
	// Duration to wait before timing out a UDP session
	_udpSessionTimeout = 60 * time.Second

	configPollInterval = 1 * time.Minute
)

type vpnServer struct {
	listener      net.Listener      // Network listener for accepting client connections
	mtu           int               // Maximum Transmission Unit size for the VPN tunnel
	offset        int               // Offset for packet processing
	clients       map[net.Conn]bool // Map to track active client connections
	vpnConnected  bool              // whether the VPN is currently connected
	configHandler *config.ConfigHandler
	tunnel        Tunnel // tunnel that manages packet forwarding
	tunnelStop    chan struct{}
	radiance      *radiance.Radiance
	mu            sync.RWMutex
}

// Opts are the options the VPN server can be configured with
type Opts struct {
	Address string
	Mtu     int
	Offset  int
}

func newVPNServer(opts *Opts) *vpnServer {
	server := &vpnServer{
		mtu:           opts.Mtu,
		offset:        opts.Offset,
		configHandler: config.NewConfigHandler(configPollInterval),
		clients:       make(map[net.Conn]bool),
	}
	return server
}

// loadConfig is used to load the configuration file. If useLocalConfig is true then we use the embedded config
func (srv *vpnServer) loadConfig(ctx context.Context, useLocalConfig bool) (*config.Config, error) {
	if useLocalConfig {
		return localconfig.LoadConfig()
	}
	cfgs, err := srv.configHandler.GetConfig(ctx)
	if err != nil {
		return nil, err
	} else if len(cfgs) == 0 {
		return nil, errors.New("no config available")
	}
	return cfgs[0], nil
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
			log.Printf("Failed to accept connection: %v", err)
			continue
		}
		s.mu.Lock()
		s.clients[conn] = true
		s.mu.Unlock()
		log.Printf("Client connected: %v", conn.RemoteAddr())
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
			log.Printf("Failed to send to %v: %v", conn.RemoteAddr(), err)
			conn.Close()
			delete(s.clients, conn)
		}
	}
}
