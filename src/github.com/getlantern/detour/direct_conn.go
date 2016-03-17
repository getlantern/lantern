package detour

import (
	"fmt"
	"net"
	"sync/atomic"

	"github.com/getlantern/eventual"
)

type directConn struct {
	Conn          *eventualConn
	network       string
	addr          string
	readFirst     int32
	detourAllowed eventual.Value
	shouldDetour  int32
}

func detector() *Detector {
	return blockDetector.Load().(*Detector)
}

func newDirectConn(network, addr string, detourAllowed eventual.Value) *directConn {
	return &directConn{
		Conn: newEventualConn(
			DialTimeout,
		),
		network:       network,
		addr:          addr,
		detourAllowed: detourAllowed,
		shouldDetour:  1, // 1 means true, will change to 0 once connected
	}
}

func (dc *directConn) Dial() (ch chan error) {
	return dc.Conn.Dial(func() (net.Conn, error) {
		conn, err := net.DialTimeout(dc.network, dc.addr, DialTimeout)
		if err == nil {
			if detector().DNSPoisoned(conn) {
				if err := conn.Close(); err != nil {
					log.Debugf("Error closing direct connection to %s: %s", dc.addr, err)
				}
				log.Debugf("Dial directly to %s, dns hijacked", dc.addr)
				return nil, fmt.Errorf("DNS hijacked")
			}
			log.Tracef("Dial directly to %s succeeded", dc.addr)
			return conn, nil
		} else if detector().TamperingSuspected(err) {
			log.Debugf("Dial directly to %s, tampering suspected: %s", dc.addr, err)
			// Since we couldn't even dial, it's okay to detour no matter whether this
			// is idempotent HTTP traffic or not.
			dc.detourAllowed.Set(true)
		} else {
			log.Debugf("Dial directly to %s failed: %s", dc.addr, err)
			//c.detourAllowed.Set(false)
		}
		return nil, err
	})
}

func (dc *directConn) Read(b []byte) chan ioResult {
	log.Tracef("Reading from directConn to %s", dc.addr)
	checker := dc.checkFollowupRead
	if atomic.CompareAndSwapInt32(&dc.readFirst, 0, 1) {
		checker = dc.checkFirstRead
	}
	ch := make(chan ioResult)
	go func() {
		result := ioResult{}
		dc.setShouldDetour(true)
		result.i, result.err = dc.doRead(b, checker)
		log.Tracef("Read %d bytes from directConn to %s, err: %v", result.i, dc.addr, result.err)
		if result.err == nil {
			dc.setShouldDetour(false)
		}
		ch <- result
	}()
	return ch
}

func (dc *directConn) Write(b []byte) chan ioResult {
	ch := make(chan ioResult)
	go func() {
		result := ioResult{}
		result.i, result.err = dc.Conn.Write(b)
		ch <- result
	}()
	return ch
}

type readChecker func([]byte, error) error

func (dc *directConn) checkFirstRead(b []byte, err error) error {
	if err == nil {
		if !detector().FakeResponse(b) {
			return nil
		}
		log.Debugf("Read %d bytes from %s directly, response is hijacked", len(b), dc.addr)
		dc.setShouldDetour(true)
		return fmt.Errorf("response is hijacked")
	}
	log.Debugf("Error while read from %s directly (first): %s", dc.addr, err)
	if detector().TamperingSuspected(err) {
		dc.setShouldDetour(true)
		return err
	}
	return err
}

func (dc *directConn) checkFollowupRead(b []byte, err error) error {
	if err != nil {
		if detector().TamperingSuspected(err) {
			log.Debugf("Seems %s is still blocked, should detour next time", dc.addr)
			dc.setShouldDetour(true)
			return err
		}
		return err
	}
	if detector().FakeResponse(b) {
		log.Tracef("%s still content hijacked, add to whitelist to try detour next time", dc.addr)
		dc.setShouldDetour(true)
		return fmt.Errorf("content hijacked")
	}
	log.Tracef("Read %d bytes from %s directly (follow-up)", len(b), dc.addr)
	return nil
}

func (dc *directConn) doRead(b []byte, checker readChecker) (int, error) {
	n, err := dc.Conn.Read(b)
	err = checker(b[:n], err)
	if err != nil {
		n = 0
	}
	return n, err
}

func (dc *directConn) Close() (err error) {
	err = dc.Conn.Close()
	return
}

func (dc *directConn) setShouldDetour(should bool) {
	log.Tracef("should detour to %s? %v", dc.addr, should)
	if should {
		atomic.StoreInt32(&dc.shouldDetour, 1)
	} else {
		atomic.StoreInt32(&dc.shouldDetour, 0)
	}

}

func (dc *directConn) ShouldDetour() bool {
	return atomic.LoadInt32(&dc.shouldDetour) == 1
}
