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
// onClose is an optional function to call after the connection has been closed,
// whether or not that was due to the connection idling.
//
// Note - idletiming.Listener does not close the underlying connections upon
// timing out, it is up to clients to handle this in their onClose callback.
func Listener(listener net.Listener, idleTimeout time.Duration, onClose func(conn net.Conn)) net.Listener {
	return &idleTimingListener{listener, idleTimeout, onClose}
}

type idleTimingListener struct {
	orig        net.Listener
	idleTimeout time.Duration
	onClose     func(conn net.Conn)
}

func (l *idleTimingListener) Accept() (c net.Conn, err error) {
	c, err = l.orig.Accept()
	if err == nil {
		var closeFn func()
		if l.onClose != nil {
			closeFn = func() {
				l.onClose(c)
			}
		}
		c = Conn(c, l.idleTimeout, closeFn)
	}
	return
}

func (l *idleTimingListener) Close() error {
	return l.orig.Close()
}

func (l *idleTimingListener) Addr() net.Addr {
	return l.orig.Addr()
}
