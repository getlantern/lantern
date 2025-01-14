package dialer

import (
	"context"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/getlantern/lantern-outline/common"
)

// Dialer is an interface that abstracts functionality for dialing proxies.
// It provides flexibility for implementing different dialing strategies
type Dialer interface {
	DialTCP(context.Context, *common.FiveTuple) (transport.StreamConn, error)
	DialUDP(*common.FiveTuple) (net.PacketConn, error)
}

// dialer is the base implementation of stream dialer used to dial proxies
type dialer struct {
	streamDialer transport.StreamDialer
	packetDialer transport.PacketListener
	addr         string
}
