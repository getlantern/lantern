package vpn

import (
	"context"
	"fmt"
	"net"
	"net/netip"

	"github.com/eycorsican/go-tun2socks/core"
	"github.com/getlantern/lantern-outline/lantern-core/common"
	"github.com/getlantern/lantern-outline/lantern-core/dialer"
)

// tcpHandler handles incoming TCP connections and establishes proxy connections.
// based on https://github.com/Jigsaw-Code/outline-apps/blob/master/client/go/outline/tun2socks/tcp.go
type tcpHandler struct {
	dialer dialer.Dialer
}

// Handle manages the lifecycle of an incoming TCP connection.
// It dials out to the target address and relays data between the connections.
func (h *tcpHandler) Handle(conn net.Conn, target *net.TCPAddr) error {
	localAddr, ok := conn.LocalAddr().(*net.TCPAddr)
	if !ok {
		conn.Close()
		return fmt.Errorf("unable to cast LocalAddr to *net.TCPAddr")
	}
	// Construct a FiveTuple from the local net.Conn and target TCPAddr.
	tuple := &common.FiveTuple{
		Network: "tcp",
		SrcIP:   netip.MustParseAddr(localAddr.IP.String()),
		SrcPort: uint16(localAddr.Port),
		DstIP:   netip.MustParseAddr(target.IP.String()),
		DstPort: uint16(target.Port),
	}
	proxyConn, err := h.dialer.DialTCP(context.Background(), tuple)
	if err != nil {
		conn.Close()
		return err
	}
	enableTCPKeepAlive(proxyConn)
	go relay(conn.(core.TCPConn), proxyConn)
	return nil
}
