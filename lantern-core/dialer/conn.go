package dialer

import (
	"crypto/tls"
	"errors"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
)

// packetConn is a wrapper around net.PacketConn that provides provides additional
// functionality for handling UDP address resolution
type packetConn struct {
	net.PacketConn
}

// WriteTo sends data to the specified address using the underlying PacketConn.
func (pc *packetConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	if udpAddr, ok := addr.(*net.UDPAddr); ok {
		return pc.PacketConn.WriteTo(b, udpAddr)
	}

	udpAddr, err := net.ResolveUDPAddr("udp", addr.String())
	if err != nil {
		return 0, err
	}
	return pc.PacketConn.WriteTo(b, udpAddr)
}

// streamConn wraps a [tls.Conn] to provide a [transport.StreamConn] interface.
// ref: outline-sdk/transport/tls/stream_dialer.go
type streamConn struct {
	*tls.Conn
	innerConn transport.StreamConn
}

var _ transport.StreamConn = (*streamConn)(nil)

func (c streamConn) CloseWrite() error {
	tlsErr := c.Conn.CloseWrite()
	return errors.Join(tlsErr, c.innerConn.CloseWrite())
}

func (c streamConn) CloseRead() error {
	return c.innerConn.CloseRead()
}
