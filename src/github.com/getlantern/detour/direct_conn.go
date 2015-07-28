package detour

import (
	"io"
	"net"
	//"strings"
	"sync/atomic"
)

type directConn struct {
	net.Conn
	addr string
	// 1 == true, 0 == false, atomic
	valid uint32
	// keep track of the total bytes read by this connection, atomic
	readBytes uint64

	// 1 == true, 0 == false, atomic
	markClose uint32
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

func DialDirect(network string, addr string, ch chan conn) {
	go func() {
		conn, err := net.DialTimeout(network, addr, TimeoutToConnect)
		detector := blockDetector.Load().(*Detector)
		if err == nil {
			if detector.DNSPoisoned(conn) {
				conn.Close()
				log.Debugf("Dial directly to %s, dns hijacked, add to whitelist", addr)
				AddToWl(addr, false)
				return
			}
			log.Tracef("Dial directly to %s succeeded", addr)
			ch <- &directConn{Conn: conn, addr: addr, valid: 1, readBytes: 0}
			return
		} else if detector.TamperingSuspected(err) {
			log.Debugf("Dial directly to %s failed, add to whitelist: %s", addr, err)
			AddToWl(addr, false)
			return
		}
		log.Debugf("Dial directly to %s failed: %s", addr, err)
	}()
}

func (dc *directConn) ConnType() connType {
	return connTypeDirect
}

func (dc *directConn) Valid() bool {
	return atomic.LoadUint32(&dc.valid) == 1
}

func (dc *directConn) SetInvalid() {
	log.Tracef("Set direct conn to %s as invalid", dc.addr)
	atomic.StoreUint32(&dc.valid, 0)
	atomic.StoreUint32(&dc.markClose, 1)
	AddToWl(dc.addr, false)
}

func (dc *directConn) FirstRead(b []byte, ch chan ioResult) {
	dc.doRead(b, checkFirstRead, ch)
}
func (dc *directConn) FollowupRead(b []byte, ch chan ioResult) {
	dc.doRead(b, checkFollowupRead, ch)
}

type readChecker func([]byte, int, error, string) bool

func checkFirstRead(b []byte, n int, err error, addr string) bool {
	detector := blockDetector.Load().(*Detector)
	if err == nil {
		if !detector.FakeResponse(b) {
			log.Tracef("Read %d bytes from %s directly (first)", n, addr)
			return true
		}
		log.Tracef("Read %d bytes from %s directly, response is hijacked", n, addr)
		AddToWl(addr, false)
	} else {
		if err == io.EOF {
			log.Tracef("Read %d bytes from %s directly, EOF", n, addr)
			return false
		}
		log.Debugf("Error while read from %s directly: %s", addr, err)
		if detector.TamperingSuspected(err) {
			AddToWl(addr, false)
		}
	}
	return false
}

func checkFollowupRead(b []byte, n int, err error, addr string) bool {
	detector := blockDetector.Load().(*Detector)
	if err != nil {
		if err == io.EOF {
			log.Tracef("Read %d bytes from %s directly, EOF", n, addr)
			return false
		}
		if detector.TamperingSuspected(err) {
			log.Tracef("Seems %s still blocked, add to whitelist to try detour next time", addr)
			AddToWl(addr, false)
			return false
		}
		log.Tracef("Read from %s directly failed: %s", addr, err)
		return false
	}
	if detector.FakeResponse(b) {
		log.Tracef("%s still content hijacked, add to whitelist to try detour next time", addr)
		AddToWl(addr, false)
		return false
	}
	log.Tracef("Read %d bytes from %s directly (follow-up)", n, addr)
	return true
}

func (dc *directConn) doRead(b []byte, checker readChecker, ch chan ioResult) {
	go func() {
		n, err := dc.Conn.Read(b)
		if atomic.LoadUint32(&dc.markClose) == 1 {
			dc.Conn.Close()
		}
		atomic.AddUint64(&dc.readBytes, uint64(n))
		defer func() { ch <- ioResult{n, err, dc} }()
		// detour will close connection at anytime,
		// so we don't treat closed connection as an error
		// errClosing in net/net.go is private, so we compare string instead
		/*if err != nil && strings.HasSuffix(err.Error(), "use of closed network connection") {
			err = nil
		}*/
		if !checker(b, n, err, dc.addr) {
			dc.SetInvalid()
		}
	}()
	return
}

func (dc *directConn) Write(b []byte, ch chan ioResult) {
	go func() {
		n, err := dc.Conn.Write(b)
		if atomic.LoadUint32(&dc.markClose) == 1 {
			dc.Conn.Close()
		}
		defer func() { ch <- ioResult{n, err, dc} }()
	}()
	return
}

func (dc *directConn) Close() {
	atomic.StoreUint32(&dc.markClose, 1)
	if atomic.LoadUint64(&dc.readBytes) > 0 && !wlTemporarily(dc.addr) {
		log.Tracef("no error found till closing, notify caller that %s can be dialed directly", dc.addr)
		// just fire it, but not blocking if the chan is nil or no reader
		select {
		case DirectAddrCh <- dc.addr:
		default:
		}
	}
}
