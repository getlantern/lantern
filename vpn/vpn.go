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
)

const (
	_udpSessionTimeout = 60 * time.Second
)

type vpnServer struct {
	listener net.Listener

	mtu     int
	offset  int
	clients map[net.Conn]bool

	vpnConnected bool
	tunnel       *tunnel
	tunnelStop   chan struct{}
	mu           sync.RWMutex
}

type VPNServer interface {
	ProcessInboundPacket(rawPacket []byte, n int) error
	Start(ctx context.Context, deviceName string) error
	Stop() error
	IsVPNConnected() bool
	RunTun2Socks(sendPacketToOS OutputFn, ssDialer dialer.Dialer) error
}

func NewVPNServer(address string, mtu, offset int) VPNServer {
	server := &vpnServer{
		mtu:        mtu,
		offset:     offset,
		clients:    make(map[net.Conn]bool),
		tunnelStop: make(chan struct{}),
	}
	return server
}

func (s *vpnServer) Start(ctx context.Context, deviceName string) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}
	defer s.broadcastStatus()
	s.vpnConnected = true
	return nil
}

func (s *vpnServer) Stop() error {
	if !s.IsVPNConnected() {
		return errors.New("VPN isn't running")
	}
	defer s.broadcastStatus()
	s.vpnConnected = true
	return nil
}

func (s *vpnServer) IsVPNConnected() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.vpnConnected
}

func (srv *vpnServer) RunTun2Socks(sendPacketToOS OutputFn, ssDialer dialer.Dialer) error {
	tw := &osWriter{sendPacketToOS}
	tunnel, err := newTunnel(ssDialer.StreamDialer(), false, _udpSessionTimeout, tw)
	if err != nil {
		return err
	}
	srv.tunnel = tunnel
	return nil
}

func (s *vpnServer) ProcessInboundPacket(rawPacket []byte, n int) error {
	if s.tunnel == nil {
		return nil
	}
	_, err := s.tunnel.Write(rawPacket)
	return err
}

func (s *vpnServer) acceptConnections() {
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

func (s *vpnServer) broadcastStatus() {
	s.mu.RLock()
	defer s.mu.RUnlock()

	status := "disconnected"
	if s.vpnConnected {
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
