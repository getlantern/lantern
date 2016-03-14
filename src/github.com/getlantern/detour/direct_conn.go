package detour

import (
	"bytes"
	"fmt"
	"net"
	"sync/atomic"

	"github.com/getlantern/eventual"
)

type directConn struct {
	Conn          *eventualConn
	network       string
	addr          string
	wroteFirst    int32
	readFirst     int32
	isHTTP        bool
	detourAllowed eventual.Value
}

const (
	BufferSize = 8192
)

var (
	detector = defaultDetector

	errDetourable = fmt.Errorf("detourable error")
)

func isDetourable(err error) bool {
	return err == errDetourable
}

func newDirectConn(network, addr string, isHTTP bool, detourAllowed eventual.Value) *directConn {
	log.Tracef("Dialing direct connection to %s", addr)
	return &directConn{
		Conn: newEventualConn(
			DialTimeout,
			BufferSize,
		),
		network:       network,
		addr:          addr,
		isHTTP:        isHTTP,
		detourAllowed: detourAllowed}
}

func (c *directConn) Dial() (ch chan struct{}) {
	return c.Conn.Dial(func() (net.Conn, error) {
		conn, err := net.DialTimeout(c.network, c.addr, DialTimeout)
		if err == nil {
			if detector.DNSPoisoned(conn) {
				if err := conn.Close(); err != nil {
					log.Debugf("Error closing direct connection to %s: %s", c.addr, err)
				}
				log.Debugf("Dial directly to %s, dns hijacked", c.addr)
				AddToWl(c.addr, false)
				return nil, fmt.Errorf("DNS hijacked")
			}
			log.Tracef("Dial directly to %s succeeded", c.addr)
			return conn, nil
		} else if detector.TamperingSuspected(err) {
			log.Debugf("Dial directly to %s, tampering suspected: %s", c.addr, err)
			AddToWl(c.addr, false)
			// Since we couldn't even dial, it's okay to detour no matter whether this
			// is idempotent HTTP traffic or not.
			c.detourAllowed.Set(true)
		} else {
			log.Debugf("Dial directly to %s failed: %s", c.addr, err)
			c.detourAllowed.Set(false)
		}
		return nil, err
	})
}

func (dc *directConn) Write(b []byte) chan ioResult {
	ch := make(chan ioResult)
	go func() {
		if atomic.CompareAndSwapInt32(&dc.wroteFirst, 0, 1) {
			dc.detourAllowed.Set(dc.isHTTP && mightBeIdempotentHTTPRequest(b))
		}
		result := ioResult{}
		result.i, result.err = dc.Conn.Write(b)
		ch <- result
	}()
	return ch
}

func (dc *directConn) Read(b []byte) chan ioResult {
	ch := make(chan ioResult)
	go func() {
		result := ioResult{}
		if atomic.CompareAndSwapInt32(&dc.readFirst, 0, 1) {
			result.i, result.err = dc.doRead(b, dc.checkFirstRead)
		} else {
			result.i, result.err = dc.doRead(b, checkFollowupRead)
		}
		ch <- result
	}()
	return ch
}

type readChecker func([]byte, int, error, string) error

func (dc *directConn) checkFirstRead(b []byte, n int, err error, addr string) error {
	if err == nil {
		if !detector.FakeResponse(b) {
			return nil
		}
		log.Debugf("Read %d bytes from %s directly, response is hijacked", n, addr)
		AddToWl(addr, false)
		return fmt.Errorf("response is hijacked")
	}
	log.Debugf("Error while read from %s directly: %s", addr, err)
	if detector.TamperingSuspected(err) {
		AddToWl(addr, false)
		// Check if it's okay to detour
		allowed, ok := dc.detourAllowed.Get(DialTimeout)
		if ok && allowed.(bool) {
			log.Tracef("Allowing detouring after encountering: %v", err)
			return errDetourable
		}
		return err
	}
	return err
}

func checkFollowupRead(b []byte, n int, err error, addr string) error {
	if err != nil {
		if detector.TamperingSuspected(err) {
			log.Debugf("Seems %s is still blocked, add to whitelist to try detour next time", addr)
			AddToWl(addr, false)
			return err
		}
		log.Tracef("Read from %s directly failed: %s", addr, err)
		return err
	}
	if detector.FakeResponse(b) {
		log.Tracef("%s still content hijacked, add to whitelist to try detour next time", addr)
		AddToWl(addr, false)
		return fmt.Errorf("content hijacked")
	}
	log.Tracef("Read %d bytes from %s directly (follow-up)", n, addr)
	return nil
}

func (dc *directConn) doRead(b []byte, checker readChecker) (int, error) {
	n, err := dc.Conn.Read(b)
	log.Tracef("Did read: %v", n)
	err = checker(b, n, err, dc.addr)
	if err != nil {
		n = 0
	}
	return n, err
}

func (dc *directConn) Close() (err error) {
	err = dc.Conn.Close()
	/*if dc.Conn.(*readBytesCounted).anyDataReceived() && !wlTemporarily(dc.addr) {
		log.Tracef("no error found till closing, notify caller that %s can be dialed directly", dc.addr)
		// just fire it, but not blocking if the chan is nil or no reader
		select {
		case DirectAddrCh <- dc.addr:
		default:
		}
	}*/
	return
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
