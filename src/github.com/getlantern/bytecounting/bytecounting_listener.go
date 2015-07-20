package bytecounting

import (
	"net"
)

// Listener is a net.Listener that wraps another net.Listener and wraps its
// net.Conns in bytecounting.Conn to track bytes read/written.
type Listener struct {
	Orig    net.Listener
	OnRead  func(bytes int64)
	OnWrite func(bytes int64)
}

func (l *Listener) Accept() (c net.Conn, err error) {
	c, err = l.Orig.Accept()
	if err == nil {
		c = &Conn{c, l.OnRead, l.OnWrite}
	}
	return
}

func (l *Listener) Close() error {
	return l.Orig.Close()
}

func (l *Listener) Addr() net.Addr {
	return l.Orig.Addr()
}
