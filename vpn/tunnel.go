package vpn

import (
	"errors"
	"sync"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/eycorsican/go-tun2socks/core"
	"github.com/eycorsican/go-tun2socks/proxy/dnsfallback"
	"github.com/getlantern/lantern-outline/dialer"
)

var (
	instance Tunnel
	tunnelMu sync.Mutex
)

// Tunnel represents the configuration of an established tunnel to a device
type tunnel struct {
	isConnected  bool
	lwipStack    core.LWIPStack
	streamDialer transport.StreamDialer
	packetDialer transport.PacketListener
	tcpHandler   core.TCPConnHandler
	udpHandler   core.UDPConnHandler

	commandServer *commandServer

	isGVisorEnabled bool
	// isUDPEnabled returns whether or not the tunnel supports UDP proxying
	// if UDP is not supported, we fall back to DNS over TCP
	isUDPEnabled bool
	udpTimeout   time.Duration
	mu           sync.Mutex
}

type OutputFn func(pkt []byte) bool

type BaseTunnel interface {
	IsConnected() bool
	Start() error
	Stop() error
}

// NewTunnel creates a new instance of Tunnel
func NewTunnel(isUDPEnabled bool, udpTimeout time.Duration) (Tunnel, error) {
	streamDialer, err := dialer.NewShadowsocks("192.168.0.253:8388", "aes-256-gcm", "mytestpassword")
	if err != nil {
		return nil, err
	}
	var packetDialer transport.PacketListener = nil
	var udpHandler core.UDPConnHandler
	if isUDPEnabled {
		var packetDialer transport.PacketListener = nil
		udpHandler = newUDPHandler(packetDialer, udpTimeout)
	} else {
		udpHandler = dnsfallback.NewUDPHandler()
	}
	cmdServer := newCommandServer()
	go cmdServer.acceptConnections()
	t := &tunnel{
		isConnected:   false,
		streamDialer:  streamDialer,
		packetDialer:  packetDialer,
		isUDPEnabled:  isUDPEnabled,
		commandServer: cmdServer,
		tcpHandler:    &tcpHandler{streamDialer},
		udpHandler:    udpHandler,
	}
	return t, nil
}

// Start starts the tunnel and broadcasts a connect status to any connected clients
func (t *tunnel) Start() error {
	isConnected := t.IsConnected()
	if isConnected {
		return errors.New("Tunnel already running")
	}
	defer t.broadcastStatus()
	t.SetConnected(true)
	return nil
}

// broadcastStatus is used to broadcast connection status changes to connected clients
func (t *tunnel) broadcastStatus() {
	if t.commandServer != nil {
		t.commandServer.broadcastStatus()
	}
}

// Stop disconnects the tunnel and broadcasts a disconnect status to any connected clients
func (t *tunnel) Stop() error {
	isConnected := t.IsConnected()
	if !isConnected {
		return errors.New("Tunnel is not running")
	}
	defer t.broadcastStatus()
	t.SetConnected(false)
	return nil
}

func (t *tunnel) SetConnected(isConnected bool) {
	t.mu.Lock()
	t.isConnected = isConnected
	t.mu.Unlock()
}

// IsConnected returns whether or not the tunnel is currently connected
func (t *tunnel) IsConnected() bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.isConnected
}
