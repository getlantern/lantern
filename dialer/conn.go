package dialer

import "net"

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
