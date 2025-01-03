package dialer

import (
	"context"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/Jigsaw-Code/outline-sdk/transport/shadowsocks"
	"github.com/getlantern/lantern-outline/common"
)

// ssDialer is used to dial shadowsocks proxies
type ssDialer struct {
	ssDialer     transport.StreamDialer
	packetDialer transport.PacketListener
	addr         string
}

func NewShadowsocks(addr, method, password string) (Dialer, error) {
	key, err := shadowsocks.NewEncryptionKey(method, password)
	if err != nil {
		return nil, err
	}
	endpoint := &transport.TCPEndpoint{Address: addr}
	dialer, err := shadowsocks.NewStreamDialer(endpoint, key)
	if err != nil {
		return nil, err
	}
	return &ssDialer{addr: addr, ssDialer: dialer}, nil
}

func (d *ssDialer) StreamDialer() transport.StreamDialer {
	return d.ssDialer
}

func (d *ssDialer) Dial(ctx context.Context, m *common.FiveTuple) (net.Conn, error) {
	return d.ssDialer.DialStream(ctx, m.RemoteAddress())
}

func (d *ssDialer) DialUDP(m *common.FiveTuple) (net.PacketConn, error) {
	pc, err := d.packetDialer.ListenPacket(context.Background())
	if err != nil {
		return nil, err
	}
	return &packetConn{PacketConn: pc}, nil
}
