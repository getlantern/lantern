package idletiming

import (
	"net"
	"time"
)

// Listener creates a net.Listener that wraps the connections obtained from an
// original net.Listener with idle timing connections that time out after the
// specified duration.
//
// idleTimeout specifies how long to wait for inactivity before considering
// connection idle.  Note - the actual timeout may be up to twice idleTimeout,
// depending on timing.
//
// If onIdle is specified, it will be called to indicate when the connection has
// idled and been closed.
func Listener(listener net.Listener, idleTimeout time.Duration, onIdle func(conn net.Conn)) net.Listener {
	if onIdle == nil {
		panic("onIdle is required")
	}

	return &idleTimingListener{listener, idleTimeout, onIdle}
}

type idleTimingListener struct {
	orig        net.Listener
	idleTimeout time.Duration
	onIdle      func(conn net.Conn)
}

func (l *idleTimingListener) Accept() (c net.Conn, err error) {
	c, err = l.orig.Accept()
	if err == nil {
		var onIdle func()
		if l.onIdle != nil {
			onIdle = func() {
				l.onIdle(c)
			}
		}
		c = Conn(c, l.idleTimeout, onIdle)
	}
	return
}

func (l *idleTimingListener) Close() error {
	return l.orig.Close()
}

func (l *idleTimingListener) Addr() net.Addr {
	return l.orig.Addr()
}
