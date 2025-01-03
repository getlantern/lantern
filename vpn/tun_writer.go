package vpn

import (
	"errors"
)

type OutputFn func(pkt []byte) bool

// osWriter implements the io.WriteCloser interface.
// It is used to send packets to the OS using an OutputFn.
type osWriter struct {
	processOutboundPacket OutputFn
}

func (w *osWriter) Write(p []byte) (n int, err error) {
	success := w.processOutboundPacket(p)
	if success {
		return len(p), nil
	}
	return 0, errors.New("failed to write packet to OS")
}

func (tw *osWriter) Close() error {
	return nil
}
