package vpn

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/eycorsican/go-tun2socks/core"
)

// udpHandler is a UDP connection handler
// based on https://github.com/Jigsaw-Code/outline-apps/blob/master/client/go/outline/tun2socks/udp.go
type udpHandler struct {
	// listener providers the packet proxying functionality
	listener transport.PacketListener
	// Maps connections from TUN to connections to the proxy.
	conns   map[core.UDPConn]net.PacketConn
	mu      sync.Mutex
	timeout time.Duration
}

func newUDPHandler(listener transport.PacketListener, timeout time.Duration) *udpHandler {
	return &udpHandler{
		conns:    make(map[core.UDPConn]net.PacketConn),
		listener: listener,
		timeout:  timeout,
	}
}

func (h *udpHandler) Connect(tunConn core.UDPConn, target *net.UDPAddr) error {
	ctx := context.Background()
	proxyConn, err := h.listener.ListenPacket(ctx)
	if err != nil {
		return err
	}
	h.mu.Lock()
	h.conns[tunConn] = proxyConn
	h.mu.Unlock()
	go h.relayPacketsFromProxy(tunConn, proxyConn)
	return nil
}

// ReceiveTo relays packets from the TUN device to the proxy. It's called by tun2socks.
func (h *udpHandler) ReceiveTo(tunConn core.UDPConn, data []byte, destAddr *net.UDPAddr) error {
	h.mu.Lock()
	proxyConn, ok := h.conns[tunConn]
	h.mu.Unlock()
	if !ok {
		return fmt.Errorf("connection %v->%v does not exist", tunConn.LocalAddr(), destAddr)
	}
	proxyConn.SetDeadline(time.Now().Add(h.timeout))
	_, err := proxyConn.WriteTo(data, destAddr)
	return err
}

// relayPacketsFromProxy relays packets from the proxy to the TUN device.
func (h *udpHandler) relayPacketsFromProxy(tunConn core.UDPConn, proxyConn net.PacketConn) {
	buf := core.NewBytes(core.BufSize)
	defer func() {
		h.close(tunConn)
		core.FreeBytes(buf)
	}()
	for {
		proxyConn.SetDeadline(time.Now().Add(h.timeout))
		n, sourceAddr, err := proxyConn.ReadFrom(buf)
		if err != nil {
			return
		}
		// No resolution will take place, the address sent by the proxy is a resolved IP.
		sourceUDPAddr, err := net.ResolveUDPAddr("udp", sourceAddr.String())
		if err != nil {
			return
		}
		_, err = tunConn.WriteFrom(buf[:n], sourceUDPAddr)
		if err != nil {
			return
		}
	}
}

func (h *udpHandler) close(tunConn core.UDPConn) {
	tunConn.Close()
	h.mu.Lock()
	defer h.mu.Unlock()
	if proxyConn, ok := h.conns[tunConn]; ok {
		proxyConn.Close()
	}
}
