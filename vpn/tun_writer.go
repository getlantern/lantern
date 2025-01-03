package vpn

import (
	"errors"
)

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
