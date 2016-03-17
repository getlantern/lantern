package detour

import (
	"bytes"
	"fmt"
	"net"
	"sync/atomic"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
)

var (
	DelayBeforeDetour = 500 * time.Millisecond
	DialTimeout       = 30 * time.Second
	DirectAddrCh      chan string
)

var (
	log           = golog.LoggerFor("detour")
	blockDetector atomic.Value
)

func init() {
	blockDetector.Store(detectorByCountry(""))
}

func SetCountry(country string) {
	blockDetector.Store(detectorByCountry(country))
}

type dialFunc func(network, addr string) (net.Conn, error)

type Timeout struct{}

func (t Timeout) Timeout() bool   { return true }
func (t Timeout) Temporary() bool { return true }
func (t Timeout) Error() string   { return "dial timeout" }

type conn struct {
	direct        *directConn
	detour        *detourConn
	expectedConns int
	closed        chan struct{}
	isHTTP        bool
	wroteFirst    int32
	detourAllowed eventual.Value
}

func knownToBeBlocked(addr string) bool {
	return whitelisted(addr)
}

func notBlocked(addr string) bool {
	return false
}

// Dialer returns a function with same signature as net.Dialer.Dial().
func Dialer(d dialFunc) dialFunc {
	return func(network, addr string) (net.Conn, error) {
		c := &conn{isHTTP: true}
		c.detourAllowed = eventual.NewValue()
		c.direct = newDirectConn(network, addr, c.detourAllowed)
		c.detour = newDetourConn(network, addr, d)
		c.closed = make(chan struct{})
		var chDialDirect = make(chan error)
		var chDialDetour = make(chan error)
		c.expectedConns = 1
		if knownToBeBlocked(addr) {
			chDialDetour = c.detour.Dial(network, addr)
		} else {
			chDialDirect = c.direct.Dial()
			if !notBlocked(addr) {
				c.expectedConns = 2
				go func() {
					time.Sleep(DelayBeforeDetour)
					chDialDetour <- <-c.detour.Dial(network, addr)
				}()
			}
		}
		t := time.NewTimer(DialTimeout)
		var err error
		for i := 0; i < c.expectedConns; i++ {
			select {
			case err = <-chDialDirect:
				if err == nil {
					return c, nil
				}
				if i == c.expectedConns-1 {
					// return the last error
					return nil, err
				}
			case err = <-chDialDetour:
				if err == nil {
					return c, nil
				}
				if i == c.expectedConns-1 {
					// return the last error
					return nil, err
				}
			case <-t.C:
				return nil, Timeout{}
			}
		}
		return c, nil
	}
}

func (c *conn) Read(b []byte) (int, error) {
	bufDirect := make([]byte, len(b))
	bufDetour := make([]byte, len(b))
	chDirect := c.direct.Read(bufDirect)
	chDetour := c.detour.Read(bufDetour)
	for i := 0; i < c.expectedConns; i++ {
		select {
		case result := <-chDirect:
			if result.err == nil || i == c.expectedConns-1 {
				_ = copy(b, bufDirect[:result.i])
				return result.i, result.err
			}
		case result := <-chDetour:
			if result.err == nil || i == c.expectedConns-1 {
				_ = copy(b, bufDetour[:result.i])
				return result.i, result.err
			}
		case <-c.closed:
			return 0, fmt.Errorf("Connection closed")
		}
	}
	panic("shoult not reach here")
}

func (c *conn) Write(b []byte) (int, error) {
	detourAllowed := true
	if atomic.CompareAndSwapInt32(&c.wroteFirst, 0, 1) {
		detourAllowed = c.isHTTP && mightBeIdempotentHTTPRequest(b)
		c.detourAllowed.Set(detourAllowed)
	}
	if !detourAllowed {
		result := <-c.direct.Write(b)
		return result.i, result.err
	}
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
	c.detourAllowed.Stop()
	c.direct.Close()
	c.detour.Close()

	log.Tracef("%s: Should detour? %v - Detourable? %v", c.direct.addr, c.direct.ShouldDetour(), c.detour.Detourable())
	if !c.detour.Detourable() {
		log.Tracef("Remove %s from blocked sites list", c.direct.addr)
		RemoveFromWl(c.direct.addr)
	} else if c.direct.ShouldDetour() {
		log.Tracef("Add %s to blocked sites list", c.direct.addr)
		AddToWl(c.direct.addr, false)
	}
	if !c.direct.ShouldDetour() {
		select {
		case DirectAddrCh <- c.direct.addr:
		default:
		}
	}
	return nil
}

func (c *conn) LocalAddr() net.Addr {
	return nil
}

func (c *conn) RemoteAddr() net.Addr {
	return nil
}

func (c *conn) SetDeadline(t time.Time) error {
	return fmt.Errorf("Not implemented")
}

func (c *conn) SetReadDeadline(t time.Time) error {
	return fmt.Errorf("Not implemented")
}

func (c *conn) SetWriteDeadline(t time.Time) error {
	return fmt.Errorf("Not implemented")
}

type ioResult struct {
	i   int
	err error
}

var nonidempotentMethods = [][]byte{
	[]byte("PUT "),
	[]byte("POST "),
	[]byte("PATCH "),
}

// Ref https://tools.ietf.org/html/rfc2616#section-9.1.2
// We consider the https handshake phase to be idemponent.
func mightBeIdempotentHTTPRequest(b []byte) bool {
	if len(b) > 4 {
		for _, m := range nonidempotentMethods {
			if bytes.HasPrefix(b, m) {
				return false
			}
		}
	}
	return true
}
