package vpn

import (
	"fmt"
	"log"
	"net"
	"sync"
)

type commandServer struct {
	listener net.Listener
	clients  map[net.Conn]bool
	mu       sync.RWMutex
	tunnel   Tunnel
}

func newCommandServer() *commandServer {
	listener, err := net.Listen("tcp", ":9999")
	if err != nil {
		log.Fatal(err)
	}
	return &commandServer{
		listener: listener,
		clients:  make(map[net.Conn]bool),
	}
}

func (s *commandServer) acceptConnections() {
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

// broadcastStatus is used to broadcast connection status changes to connected clients
func (s *commandServer) broadcastStatus() {
	s.mu.RLock()
	defer s.mu.RUnlock()

	status := "disconnected"
	if s.tunnel.IsConnected() {
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
