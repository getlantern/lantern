package vpn

import (
	"context"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/eycorsican/go-tun2socks/core"
)

// NewTCPHandler returns a TCP connection handler based on
// https://github.com/Jigsaw-Code/outline-apps/blob/master/client/go/outline/tun2socks/tcp.go
type tcpHandler struct {
	dialer transport.StreamDialer
}

func (h *tcpHandler) Handle(conn net.Conn, target *net.TCPAddr) error {
	proxyConn, err := h.dialer.DialStream(context.Background(), target.String())
	if err != nil {
		return err
	}
	// TODO: Request upstream to make `conn` a `core.TCPConn` so we can avoid this type assertion.
	go relay(conn.(core.TCPConn), proxyConn)
	return nil
}
