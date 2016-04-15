package detour

import (
	"bytes"
	"net"
	"sync/atomic"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
)

var (
	DelayBeforeDetour = 500 * time.Millisecond
	DialTimeout       = 30 * time.Second
)

var (
	log           = golog.LoggerFor("detour")
	directAddrCh  atomic.Value
	blockDetector atomic.Value
)

func init() {
	SetCountry("")
}

func SetDirectAddrCh(ch chan string) {
	directAddrCh.Store(ch)
}

func SetCountry(country string) {
	blockDetector.Store(detectorByCountry(country))
}

type dialFunc func(network, addr string) (net.Conn, error)

type ErrDialTimeout struct{}
type ErrClosed struct{}

func (t ErrDialTimeout) Timeout() bool   { return true }
func (t ErrDialTimeout) Temporary() bool { return true }
func (t ErrDialTimeout) Error() string   { return "dial timeout" }
func (t ErrClosed) Timeout() bool        { return false }
func (t ErrClosed) Temporary() bool      { return false }
func (t ErrClosed) Error() string        { return "connection closed" }

type conn struct {
	addr          string
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
		// TODO: provide meaningful isHTTP
		detourAllowed := eventual.NewValue()
		c := &conn{
			addr:          addr,
			isHTTP:        true,
			detourAllowed: detourAllowed,
			direct:        newDirectConn(network, addr),
			detour:        newDetourConn(network, addr, d),
			closed:        make(chan struct{}),
			expectedConns: 1,
		}
		var chDialDirect = make(chan error)
		var chDialDetour = make(chan error)
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
		var lastError error
		for i := 0; i < c.expectedConns; i++ {
			select {
			case lastError = <-chDialDirect:
				if lastError == nil {
					return c, nil
				}
				// Since we couldn't even dial, it's okay to detour no matter whether this
				// is idempotent HTTP traffic or not.
				c.detourAllowed.Set(true)
			case lastError = <-chDialDetour:
				if lastError == nil {
					return c, nil
				}
			case <-t.C:
				return nil, ErrDialTimeout{}
			}
		}
		return nil, lastError
	}
}

func (c *conn) Read(b []byte) (int, error) {
	allowed, valid := c.detourAllowed.Get(0)
	if valid && !allowed.(bool) {
		log.Tracef("detour is not allowed to %s, read directly", c.addr)
		result := <-c.direct.Read(b)
		return result.i, result.err
	}
	bufDirect := make([]byte, len(b))
	bufDetour := make([]byte, len(b))
	chDirect := c.direct.Read(bufDirect)
	chDetour := c.detour.Read(bufDetour)
	var result ioResult
	for i := 0; i < c.expectedConns; i++ {
		select {
		case result = <-chDirect:
			if result.err == nil {
				_ = copy(b, bufDirect[:result.i])
				return result.i, nil
			}
		case result := <-chDetour:
			if result.err == nil {
				_ = copy(b, bufDetour[:result.i])
				return result.i, nil
			}
		case <-c.closed:
			return 0, ErrClosed{}
		}
	}
	return 0, result.err
}

func (c *conn) Write(b []byte) (int, error) {
	if atomic.CompareAndSwapInt32(&c.wroteFirst, 0, 1) {
		detourAllowed := c.isHTTP && mightBeIdempotentHTTPRequest(b)
		c.detourAllowed.Set(detourAllowed)
	}
	// make sure we got the value previously set
	allowed, valid := c.detourAllowed.Get(1 * time.Hour)
	if valid && !allowed.(bool) {
		log.Tracef("detour is not allowed to %s, write directly", c.addr)
		result := <-c.direct.Write(b)
		return result.i, result.err
	}

	buf := make([]byte, len(b))
	_ = copy(buf, b)
	select {
	case result := <-c.direct.Write(buf):
		return result.i, result.err
	case result := <-c.detour.Write(buf):
		return result.i, result.err
	case <-c.closed:
		return 0, ErrClosed{}
	}
}

func (c *conn) Close() error {
	close(c.closed)
	c.detourAllowed.Stop()
	_ = c.direct.Close()
	_ = c.detour.Close()

	log.Tracef("%s: Should detour? %v - Detourable? %v", c.addr, c.direct.ShouldDetour(), c.detour.Detourable())
	allowed, valid := c.detourAllowed.Get(0)
	if valid && allowed.(bool) && !c.detour.Detourable() {
		log.Tracef("Remove %s from blocked sites list", c.addr)
		RemoveFromWl(c.addr)
	} else if c.direct.ShouldDetour() {
		log.Tracef("Add %s to blocked sites list", c.addr)
		AddToWl(c.addr, false)
	}
	if !c.direct.ShouldDetour() {
		if ch := directAddrCh.Load(); ch != nil {
			select {
			case ch.(chan string) <- c.addr:
			default:
			}
		}
	}
	return nil
}

func (c *conn) LocalAddr() net.Addr {
	addr := c.direct.LocalAddr()
	if addr == nil {
		addr = c.detour.LocalAddr()
	}
	return addr
}

func (c *conn) RemoteAddr() net.Addr {
	addr := c.direct.RemoteAddr()
	if addr == nil {
		addr = c.detour.RemoteAddr()
	}
	return addr
}

func (c *conn) SetDeadline(t time.Time) error {
	e1 := c.direct.SetDeadline(t)
	e2 := c.detour.SetDeadline(t)
	if e1 != nil {
		return e1
	}
	return e2
}

func (c *conn) SetReadDeadline(t time.Time) error {
	e1 := c.direct.SetReadDeadline(t)
	e2 := c.detour.SetReadDeadline(t)
	if e1 != nil {
		return e1
	}
	return e2
}

func (c *conn) SetWriteDeadline(t time.Time) error {
	e1 := c.direct.SetWriteDeadline(t)
	e2 := c.detour.SetWriteDeadline(t)
	if e1 != nil {
		return e1
	}
	return e2
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
