package dialer

import (
	"context"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/common"
)

var (
	log = golog.LoggerFor("dialer")
)

// Dialer is an interface that abstracts functionality for dialing proxies.
// It provides flexibility for implementing different dialing strategies
type Dialer interface {
	// DialStream establishes a connection to the remote address using the Shadowsocks dialer.
	DialStream(ctx context.Context, remoteAddr string) (transport.StreamConn, error)
	// DialTCP establishes a TCP connection to the target specified by the FiveTuple.
	DialTCP(context.Context, *common.FiveTuple) (transport.StreamConn, error)
	// DialUDP establishes a UDP connection to the target specified by the FiveTuple.
	DialUDP(*common.FiveTuple) (net.PacketConn, error)
}
