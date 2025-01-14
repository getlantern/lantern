package vpn

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net"
	"sync"
	"time"

	"github.com/getlantern/lantern-outline/dialer"
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
	tunnel        *tunnel           // tunnel that manages packet forwarding
	tunnelStop    chan struct{}
	configHandler *config.ConfigHandler
	dialer        dialer.Dialer
	mu            sync.RWMutex
}

// VPNServer defines the methods required to manage the VPN server
type VPNServer interface {
	ProcessInboundPacket(rawPacket []byte, n int) error
	Start(ctx context.Context) error
	StartTun2Socks(ctx context.Context, bridge IOSBridge) error
	Stop() error
	IsVPNConnected() bool
}

// IOSBridge defines the interface for interaction with Swift.
type IOSBridge interface {
	ProcessOutboundPacket(pkt []byte) bool
	ExcludeRoute(route string) bool
}

// NewVPNServer initializes and returns a new instance of vpnServer
func NewVPNServer(address string, mtu, offset int) VPNServer {
	server := &vpnServer{
		mtu:           mtu,
		offset:        offset,
		configHandler: config.NewConfigHandler(configPollInterval),
		tunnel:        newTunnel(false, _udpSessionTimeout),
		clients:       make(map[net.Conn]bool),
		tunnelStop:    make(chan struct{}),
	}
	return server
}

// Start initializes the tunnel using the provided parameters and starts the VPN server.
func (s *vpnServer) Start(ctx context.Context) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}
	//go s.acceptConnections(ctx)
	return nil
}

// StartTun2Socks initializes the Tun2Socks tunnel with the provided IOSBridge adapter.
func (s *vpnServer) StartTun2Socks(ctx context.Context, bridge IOSBridge) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}
	go s.startTun2Socks(ctx, bridge)
	return nil
}

// startTun2Socks configures and starts the Tun2Socks tunnel using the provided parameters.
func (srv *vpnServer) startTun2Socks(ctx context.Context, bridge IOSBridge) error {
	cfg, err := srv.configHandler.GetConfig(ctx)
	if err != nil {
		return err
	}

	dialer, err := dialer.NewDialer(cfg)
	if err != nil {
		return err
	}
	// Exclude proxy server address from the VPN routing table
	if ok := bridge.ExcludeRoute(cfg.Addr); !ok {
		return fmt.Errorf("unable to exclude route: %s", cfg.Addr)
	}
	tunWriter := &osWriter{bridge.ProcessOutboundPacket}
	if err := srv.tunnel.Start(dialer, tunWriter); err != nil {
		log.Printf("Error starting tunnel: %v", err)
		return err
	}
	defer srv.broadcastStatus()
	srv.setConnected(true)
	return nil
}

// Stop stops the VPN server and closes the tunnel.
func (s *vpnServer) Stop() error {
	if !s.IsVPNConnected() {
		return errors.New("VPN isn't running")
	}
	defer s.broadcastStatus()
	s.setConnected(false)

	if s.tunnel != nil {
		if err := s.tunnel.Close(); err != nil {
			return err
		}
	}
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

// ProcessInboundPacket handles a packet received from the TUN device.
func (s *vpnServer) ProcessInboundPacket(rawPacket []byte, n int) error {
	if s.tunnel == nil {
		return nil
	}
	_, err := s.tunnel.Write(rawPacket)
	return err
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
