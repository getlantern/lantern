package enproxy

import (
	"fmt"
	"net"
	"sync"

	"github.com/getlantern/idletiming"
)

// lazyConn is a lazily initializing conn that makes sure it is only initialized
// once.  Using these allows us to ensure that we only create one connection per
// connection id, but to still support doing the Dial calls concurrently.
type lazyConn struct {
	p       *Proxy
	id      string
	addr    string
	hitEOF  bool
	connOut net.Conn
	err     error
	mutex   sync.Mutex
}

func (p *Proxy) newLazyConn(id string, addr string) *lazyConn {
	return &lazyConn{
		p:    p,
		id:   id,
		addr: addr,
	}
}

func (l *lazyConn) get() (conn net.Conn, err error) {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	if l.err != nil {
		// If dial already resulted in an error, return that
		return nil, err
	}
	if l.connOut == nil {
		// Lazily dial out
		conn, err := l.p.Dial(l.addr)
		if err != nil {
			l.err = fmt.Errorf("Unable to dial out to %s: %s", l.addr, err)
			return nil, l.err
		}

		// Wrap the connection in an idle timing one
		l.connOut = idletiming.Conn(conn, l.p.IdleTimeout, func() {
			l.p.connMapMutex.Lock()
			defer l.p.connMapMutex.Unlock()
			delete(l.p.connMap, l.id)
			conn.Close()
		})
	}

	return l.connOut, l.err
}
