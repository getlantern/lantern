package detour

import (
	"fmt"
	"net"
	"sync/atomic"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
)

var DelayBeforeDetour = 500 * time.Millisecond
var DialTimeout = 30 * time.Second
var DirectAddrCh chan string
var log = golog.LoggerFor("detour")
var blockDetector atomic.Value

func init() {
	blockDetector.Store(detectorByCountry(""))
}

type dialFunc func(network, addr string) (net.Conn, error)

type conn struct {
	direct        *directConn
	detour        *detourConn
	closed        chan struct{}
	detourAllowed eventual.Value
}

func SetCountry(country string) {
	blockDetector.Store(detectorByCountry(country))
}

func knownToBeBlocked(addr string) bool {
	return false
}

func knownToBeUnblocked(addr string) bool {
	return false
}

// Dialer returns a function with same signature as net.Dialer.Dial().
func Dialer(d dialFunc) dialFunc {
	return func(network, addr string) (net.Conn, error) {
		c := &conn{}
		c.detourAllowed = eventual.NewValue()
		c.direct = newDirectConn(network, addr, false /*isHTTP*/, c.detourAllowed)
		c.detour = &detourConn{}
		c.closed = make(chan struct{})
		var chDialDirect = make(chan struct{})
		var chDialDetour = make(chan struct{})
		if !knownToBeBlocked(addr) {
			chDialDirect = c.direct.Dial()
		}
		if !knownToBeUnblocked(addr) {
			go func() {
				time.Sleep(DelayBeforeDetour)
				chDialDetour <- <-c.detour.Dial(network, addr)
			}()
		}
		select {
		case <-chDialDirect:
		case <-chDialDetour:
		}
		return c, nil
	}
}

func (c *conn) Read(b []byte) (int, error) {
	select {
	case result := <-c.direct.Read(b):
		return result.i, result.err
	case result := <-c.detour.Read(b):
		return result.i, result.err
	case <-c.closed:
		return 0, fmt.Errorf("Connection closed")
	}
}

func (c *conn) Write(b []byte) (int, error) {
	select {
	case result := <-c.direct.Write(b):
		return result.i, result.err
	case result := <-c.detour.Write(b):
		return result.i, result.err
	case <-c.closed:
		return 0, fmt.Errorf("Connection closed")
	}
}

func (c *conn) Close() error {
	close(c.closed)
	c.direct.Close()
	c.detour.Close()
	return nil
}

func (c *conn) LocalAddr() net.Addr {
	return nil
}

func (c *conn) RemoteAddr() net.Addr {
	return nil
}

func (c *conn) SetDeadline(t time.Time) error {
	return nil
}

func (c *conn) SetReadDeadline(t time.Time) error {
	return nil
}

func (c *conn) SetWriteDeadline(t time.Time) error {
	return nil
}

type ioResult struct {
	i   int
	err error
}
