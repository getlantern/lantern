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

// tunnel represents the configuration and state of an established tunnel to a device.
// It manages the interaction between the TUN interface and the proxy, enabling the
// forwarding of TCP and UDP traffic
type tunnel struct {
	isConnected     bool
	lwipStack       core.LWIPStack // The LWIP stack used for managing the virtual network
	streamDialer    transport.StreamDialer
	packetDialer    transport.PacketListener
	tcpHandler      core.TCPConnHandler
	udpHandler      core.UDPConnHandler
	isGVisorEnabled bool
	isUDPEnabled    bool // isUDPEnabled returns whether or not the tunnel supports UDP proxying
	udpTimeout      time.Duration
	mu              sync.Mutex
}

// newTunnel creates and initializes a new instance of tunnel with the given parameters
func newTunnel(streamDialer transport.StreamDialer, isUDPEnabled bool, udpTimeout time.Duration) *tunnel {
	t := &tunnel{
		lwipStack:    core.NewLWIPStack(),
		streamDialer: streamDialer,
		packetDialer: nil,
		isUDPEnabled: isUDPEnabled,
		udpTimeout:   udpTimeout,
	}
	return t
}

// Start actually starts running the tunnel by registering connection handlers and the output function
// to write packets from LWIP to the TUN interface
func (t *tunnel) Start(tunWriter io.WriteCloser) error {
	tcpHandler := &tcpHandler{t.streamDialer}
	var udpHandler core.UDPConnHandler
	if t.isUDPEnabled {
		var packetDialer transport.PacketListener = nil
		udpHandler = newUDPHandler(packetDialer, t.udpTimeout)
	} else {
		// If UDP is disabled, fallback to a DNS handler
		udpHandler = dnsfallback.NewUDPHandler()
	}
	// Register the output function to write packets from LWIP to the TUN interface
	core.RegisterOutputFn(func(data []byte) (int, error) {
		return tunWriter.Write(data)
	})
	// Register connection handlers
	core.RegisterTCPConnHandler(tcpHandler)
	core.RegisterUDPConnHandler(udpHandler)
	return nil
}

func (t *tunnel) Write(data []byte) (int, error) {
	if t.lwipStack == nil {
		return 0, errors.New("Failed to write, network stack closed")
	}
	return t.lwipStack.Write(data)
}

// Close closes the tunnel and LWIP stack
func (t *tunnel) Close() error {
	if t.lwipStack != nil {
		return t.lwipStack.Close()
	}
	return nil
}
