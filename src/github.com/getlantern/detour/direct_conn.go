package detour

import (
	"fmt"
	"net"
	"sync/atomic"
)

type directConn struct {
	net.Conn
	addr string
	// keep track of the total bytes read by this connection, atomic
	readBytes uint64
	// a flag telling if connection is closed
	closed uint32
}

var (
	blockDetector atomic.Value
)

// SetCountry sets the ISO 3166-1 alpha-2 country code
// to load country specific detection rules
func SetCountry(country string) {
	blockDetector.Store(detectorByCountry(country))
}

func init() {
	blockDetector.Store(detectorByCountry(""))
}

func dialDirect(network string, addr string, ch chan conn) {
	go func() {
		log.Tracef("Dialing direct connection to %s", addr)
		conn, err := net.DialTimeout(network, addr, TimeoutToConnect)
		detector := blockDetector.Load().(*Detector)
		if err == nil {
			if detector.DNSPoisoned(conn) {
				if err := conn.Close(); err != nil {
					log.Debugf("Error closing direct connection to %s: %s", addr, err)
				}
				log.Debugf("Dial directly to %s, dns hijacked, add to whitelist", addr)
				AddToWl(addr, false)
				return
			}
			log.Tracef("Dial directly to %s succeeded", addr)
			ch <- &directConn{Conn: conn, addr: addr, readBytes: 0}
			return
		} else if detector.TamperingSuspected(err) {
			log.Debugf("Dial directly to %s, tampering suspected: %s", addr, err)
			return
		}
		log.Debugf("Dial directly to %s failed: %s", addr, err)
	}()
}

func (dc *directConn) ConnType() connType {
	return connTypeDirect
}

func (dc *directConn) FirstRead(b []byte, ch chan ioResult) {
	dc.doRead(b, checkFirstRead, ch)
}
func (dc *directConn) FollowupRead(b []byte, ch chan ioResult) {
	dc.doRead(b, checkFollowupRead, ch)
}

type readChecker func([]byte, int, error, string) error

func checkFirstRead(b []byte, n int, err error, addr string) error {
	detector := blockDetector.Load().(*Detector)
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
	}
	return err
}

func checkFollowupRead(b []byte, n int, err error, addr string) error {
	detector := blockDetector.Load().(*Detector)
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

func (dc *directConn) doRead(b []byte, checker readChecker, ch chan ioResult) {
	go func() {
		n, err := dc.Conn.Read(b)
		err = checker(b, n, err, dc.addr)
		if err != nil {
			b = nil
			n = 0
		} else {
			atomic.AddUint64(&dc.readBytes, uint64(n))
		}
		ch <- ioResult{n, err, dc}
	}()
	return
}

func (dc *directConn) Write(b []byte, ch chan ioResult) {
	go func() {
		n, err := dc.Conn.Write(b)
		ch <- ioResult{n, err, dc}
	}()
}

func (dc *directConn) Close() (err error) {
	err = dc.Conn.Close()
	if atomic.LoadUint64(&dc.readBytes) > 0 && !wlTemporarily(dc.addr) {
		log.Tracef("no error found till closing, notify caller that %s can be dialed directly", dc.addr)
		// just fire it, but not blocking if the chan is nil or no reader
		select {
		case DirectAddrCh <- dc.addr:
		default:
		}
	}
	atomic.StoreUint32(&dc.closed, 1)
	return
}

func (dc *directConn) Closed() bool {
	return atomic.LoadUint32(&dc.closed) == 1
}
