package detour

import (
	"bytes"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/getlantern/eventual"
)

// A Conn that uses an eventually available underlying Conn. Writes will go into
// a bounded buffer until the underlying Conn is available. Reads will be
// blocked until the underlying Conn is available or times out.
type eventualConn struct {
	conn         eventual.Value
	timeout      time.Duration
	writeBuf     bytes.Buffer
	writeMutex   sync.Mutex
	writeThrough bool
}

func newEventualConn(timeout time.Duration) *eventualConn {
	conn := &eventualConn{
		conn:    eventual.NewValue(),
		timeout: timeout,
	}

	return conn
}

func (conn *eventualConn) Dial(dial func() (net.Conn, error)) chan error {
	ch := make(chan error)
	// Dial on a goroutine and report the result
	go func() {
		c, err := dial()
		if err != nil {
			conn.conn.Set(err)
			ch <- err
			return
		}
		conn.writeMutex.Lock()
		if conn.writeBuf.Len() > 0 {
			log.Trace("Flushing write buffer")
			_, err := conn.writeBuf.WriteTo(c)
			if err != nil {
				conn.conn.Set(fmt.Errorf("Unable to flush write buffer: %v", err))
			}
		}
		conn.conn.Set(c)
		conn.writeThrough = true
		conn.writeMutex.Unlock()
		ch <- nil
	}()
	return ch
}

func (conn *eventualConn) Read(b []byte) (n int, err error) {
	c, err := conn.getConn()
	if err != nil {
		return 0, err
	}
	return c.Read(b)
}

func (conn *eventualConn) Write(b []byte) (n int, err error) {
	conn.writeMutex.Lock()
	defer conn.writeMutex.Unlock()
	if !conn.writeThrough {
		log.Trace("Writing to buffer")
		return conn.writeBuf.Write(b)
	} else {
		log.Trace("Writing to underlying conn")
		c, err := conn.getConn()
		if err != nil {
			return 0, err
		}
		return c.Write(b)
	}
}

func (conn *eventualConn) Close() error {
	conn.conn.Stop()
	c, err := conn.getConn()
	if err != nil {
		return err
	}
	return c.Close()
}

func (conn *eventualConn) LocalAddr() net.Addr {
	c, err := conn.getConn()
	if err != nil {
		panic(err)
	}
	return c.LocalAddr()
}

func (conn *eventualConn) RemoteAddr() net.Addr {
	c, err := conn.getConn()
	if err != nil {
		panic(err)
	}
	return c.RemoteAddr()
}

func (conn *eventualConn) SetDeadline(t time.Time) error {
	c, err := conn.getConn()
	if err != nil {
		return err
	}
	return c.SetDeadline(t)
}

func (conn *eventualConn) SetReadDeadline(t time.Time) error {
	c, err := conn.getConn()
	if err != nil {
		return err
	}
	return c.SetReadDeadline(t)
}

func (conn *eventualConn) SetWriteDeadline(t time.Time) error {
	c, err := conn.getConn()
	if err != nil {
		return err
	}
	return c.SetWriteDeadline(t)
}

func (conn *eventualConn) getConn() (net.Conn, error) {
	_c, ok := conn.conn.Get(conn.timeout)
	if !ok {
		return nil, fmt.Errorf("Unable to obtain connection within timeout")
	}
	if _c == nil {
		return nil, fmt.Errorf("No connection")
	}
	err, ok := _c.(error)
	if ok {
		return nil, err
	}
	return _c.(net.Conn), nil
}
