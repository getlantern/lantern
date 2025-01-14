package dialer

import (
	"context"
	"fmt"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/getlantern/lantern-outline/common"
	"github.com/getlantern/radiance/config"
	rtransport "github.com/getlantern/radiance/transport"
)

// NewDialer creates a new Dialer from the given Radiance config.
func NewDialer(cfg *config.Config) (Dialer, error) {
	streamDialer, err := rtransport.DialerFrom(cfg)
	if err != nil {
		return nil, err
	}
	addr := fmt.Sprintf("%s:%d", cfg.Addr, cfg.Port)
	return &dialer{
		addr:         addr,
		streamDialer: streamDialer,
	}, nil
}

// DialTCP establishes a TCP connection to the target specified by the FiveTuple.
func (d *dialer) DialTCP(ctx context.Context, m *common.FiveTuple) (transport.StreamConn, error) {
	return d.streamDialer.DialStream(ctx, m.RemoteAddress())
}

// DialUDP establishes a UDP connection using the packetDialer.
func (d *dialer) DialUDP(m *common.FiveTuple) (net.PacketConn, error) {
	pc, err := d.packetDialer.ListenPacket(context.Background())
	if err != nil {
		return nil, err
	}
	return &packetConn{PacketConn: pc}, nil
}
