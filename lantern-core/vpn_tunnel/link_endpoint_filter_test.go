//go:build with_gvisor

package vpn_tunnel_test

import (
	"testing"

	"github.com/sagernet/gvisor/pkg/tcpip"
	"github.com/sagernet/gvisor/pkg/tcpip/stack"
	tun "github.com/sagernet/sing-tun"
)

// Keep the detach contract covered on non-Linux Go CI too.
func TestLinkEndpointFilterPreservesDetach(t *testing.T) {
	endpoint := &recordingEndpoint{}
	filter := &tun.LinkEndpointFilter{LinkEndpoint: endpoint}
	dispatcher := make(packetDispatcher, 2)
	filter.Attach(dispatcher)
	if endpoint.dispatcher == nil {
		t.Fatal("Attach discarded the network dispatcher")
	}
	packet := stack.NewPacketBuffer(stack.PacketBufferOptions{})
	defer packet.DecRef()
	endpoint.dispatcher.DeliverNetworkPacket(0, packet)
	if len(dispatcher) != 1 {
		t.Fatal("attached filter did not forward exactly one network packet")
	}
	filter.Attach(nil)
	if endpoint.dispatcher != nil {
		t.Fatal("Attach(nil) did not forward the literal nil detach signal to the underlying endpoint")
	}
}

type recordingEndpoint struct {
	stack.LinkEndpoint
	dispatcher stack.NetworkDispatcher
}

func (e *recordingEndpoint) Attach(dispatcher stack.NetworkDispatcher) {
	e.dispatcher = dispatcher
}

type packetDispatcher chan struct{}

func (d packetDispatcher) DeliverNetworkPacket(tcpip.NetworkProtocolNumber, *stack.PacketBuffer) {
	select {
	case d <- struct{}{}:
	default:
	}
}

func (packetDispatcher) DeliverLinkPacket(tcpip.NetworkProtocolNumber, *stack.PacketBuffer) {}
