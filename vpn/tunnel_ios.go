package vpn

import (
	"errors"
	"time"

	"github.com/eycorsican/go-tun2socks/core"
)

const udpTimeout = 30 * time.Second

type Tunnel interface {
	BaseTunnel
	ProcessInboundPacket(rawPacket []byte, n int) error
	Run(tunWriter OutputFn) error
}

// osWriter implements the io.WriteCloser interface.
// It is used to send packets to the OS using an OutputFn.
type osWriter struct {
	sendPacketToOS OutputFn
}

func (w *osWriter) Write(p []byte) (n int, err error) {
	success := w.sendPacketToOS(p)
	if success {
		return len(p), nil
	}
	return 0, errors.New("failed to write packet to OS")
}

func (tw *osWriter) Close() error {
	return nil
}

func (t *tunnel) ProcessInboundPacket(rawPacket []byte, n int) error {
	if !t.isConnected {
		return errors.New("Failed to write, network stack closed")
	}
	_, err := t.lwipStack.Write(rawPacket)
	return err
}

func (t *tunnel) Run(sendPacketToOS OutputFn) error {
	tunWriter := &osWriter{sendPacketToOS}
	core.RegisterOutputFn(func(data []byte) (int, error) {
		return tunWriter.Write(data)
	})
	t.lwipStack = core.NewLWIPStack()
	// register connection handlers
	core.RegisterTCPConnHandler(t.tcpHandler)
	core.RegisterUDPConnHandler(t.udpHandler)
	return t.Start()
}
