package vpn

import (
	"errors"
	"io"
	"sync"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/eycorsican/go-tun2socks/core"
	"github.com/eycorsican/go-tun2socks/proxy/dnsfallback"
)

// Tunnel represents the configuration of an established tunnel to a device
type tunnel struct {
	isConnected  bool
	lwipStack    core.LWIPStack
	streamDialer transport.StreamDialer
	packetDialer transport.PacketListener
	tcpHandler   core.TCPConnHandler
	udpHandler   core.UDPConnHandler

	isGVisorEnabled bool
	// isUDPEnabled returns whether or not the tunnel supports UDP proxying
	// if UDP is not supported, we fall back to DNS over TCP
	isUDPEnabled bool
	udpTimeout   time.Duration
	mu           sync.Mutex
}

type OutputFn func(pkt []byte) bool

// newTunnel creates a new instance of Tunnel
func newTunnel(streamDialer transport.StreamDialer, isUDPEnabled bool, udpTimeout time.Duration, tunWriter io.WriteCloser) (*tunnel, error) {
	var udpHandler core.UDPConnHandler
	if isUDPEnabled {
		var packetDialer transport.PacketListener = nil
		udpHandler = newUDPHandler(packetDialer, udpTimeout)
	} else {
		udpHandler = dnsfallback.NewUDPHandler()
	}
	core.RegisterOutputFn(func(data []byte) (int, error) {
		return tunWriter.Write(data)
	})
	lwipStack := core.NewLWIPStack()
	tcpHandler := &tcpHandler{streamDialer}
	t := &tunnel{
		isConnected:  true,
		lwipStack:    lwipStack,
		streamDialer: streamDialer,
		packetDialer: nil,
		isUDPEnabled: isUDPEnabled,
		tcpHandler:   tcpHandler,
		udpHandler:   udpHandler,
	}
	core.RegisterTCPConnHandler(tcpHandler)
	core.RegisterUDPConnHandler(udpHandler)
	return t, nil
}

func (t *tunnel) Write(data []byte) (int, error) {
	if !t.isConnected {
		return 0, errors.New("Failed to write, network stack closed")
	}
	return t.lwipStack.Write(data)
}
