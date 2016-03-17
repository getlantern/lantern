package detour

import (
	"net"
	"sync/atomic"
)

type detourConn struct {
	Conn       *eventualConn
	network    string
	addr       string
	dialFN     dialFunc
	detourable int32
	closed     int32
}

func newDetourConn(network, addr string, d dialFunc) *detourConn {
	return &detourConn{
		Conn: newEventualConn(
			DialTimeout,
		),
		network:    network,
		addr:       addr,
		dialFN:     d,
		detourable: 1,
	}
}

func (c *detourConn) Dial(network, addr string) (ch chan error) {
	return c.Conn.Dial(func() (net.Conn, error) {
		c, err := c.dialFN(c.network, c.addr)
		return c, err
	})
}

func (c *detourConn) Read(b []byte) chan ioResult {
	ch := make(chan ioResult)
	go func() {
		c.setDetourable(false)
		i, err := c.Conn.Read(b)
		log.Tracef("Read %d bytes from detourConn to %s, err: %v", i, c.addr, err)
		if err == nil {
			c.setDetourable(true)
		}
		ch <- ioResult{i, err}
	}()
	return ch
}

func (c *detourConn) Write(b []byte) chan ioResult {
	ch := make(chan ioResult)
	go func() {
		i, err := c.Conn.Write(b)
		ch <- ioResult{i, err}
	}()
	return ch
}

func (c *detourConn) Close() (err error) {
	if atomic.CompareAndSwapInt32(&c.closed, 0, 1) {
		err = c.Conn.Close()
	}
	return
}

func (c *detourConn) isClosed() bool {
	return atomic.LoadInt32(&c.closed) == 1
}

func (c *detourConn) setDetourable(b bool) {
	if b {
		log.Tracef("Set %s as detourable", c.addr)
		atomic.StoreInt32(&c.detourable, 1)
	} else {
		log.Tracef("Set %s as not detourable", c.addr)
		atomic.StoreInt32(&c.detourable, 0)
	}
}

func (c *detourConn) Detourable() bool {
	return atomic.LoadInt32(&c.detourable) == 1
}
