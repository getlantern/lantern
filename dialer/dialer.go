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
	StreamDialer() transport.StreamDialer
	Dial(context.Context, *common.FiveTuple) (transport.StreamConn, error)
	DialUDP(*common.FiveTuple) (net.PacketConn, error)
}
