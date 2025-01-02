package dialer

import (
	"context"
	"net"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/getlantern/lantern-outline/common"
)

type Dialer interface {
	transport.StreamDialer
	Dial(context.Context, *common.FiveTuple) (net.Conn, error)
	DialUDP(*common.FiveTuple) (net.PacketConn, error)
}
