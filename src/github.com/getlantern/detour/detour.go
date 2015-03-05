package detour

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("detour")
	// if dial or read exceeded this timeout, we consider switch to detour
	timeoutToDetour = 1 * time.Second

	muWhitelist sync.RWMutex
	whitelist   = make(map[string]bool)
)

type dialFunc func(network, addr string) (net.Conn, error)

type detourConn struct {
	muConn sync.RWMutex
	// the actual connection, will change so protect it
	// can't user atomic.Value as the concrete type may vary
	conn net.Conn

	// don't access directly, use inState() and setState() instead
	state uint32

	// the function to dial detour if the site to connect seems blocked
	dialDetour dialFunc

	muBuf sync.Mutex
	// keep track of bytes sent through normal connection
	// so we can resend them when detour
	buf bytes.Buffer

	network, addr string
	readDeadline  time.Time
	writeDeadline time.Time
}

const (
	stateInitial = iota
	stateDirect
	stateDetour
	stateWhitelistCandidate
	stateWhitelist
)

var statesDesc = []string{
	"INITIALLY",
	"DIRECTLY",
	"DETOURED",
	"WHITELIST CANDIDATE",
	"WHITELISTED",
}

// SetTimeout sets the timeout so if dial or read exceeds this timeout, we consider switch to detour
// The value depends on OS and browser and defaults to 1s
// For Windows XP, find TcpMaxConnectRetransmissions in http://support2.microsoft.com/default.aspx?scid=kb;en-us;314053
func SetTimeout(t time.Duration) {
	timeoutToDetour = t
}

func Dialer(dialer dialFunc) dialFunc {
	return func(network, addr string) (conn net.Conn, err error) {
		dc := &detourConn{dialDetour: dialer, network: network, addr: addr}
		if !whitelisted(addr) {
			dc.setState(stateInitial)
			dc.conn, err = net.DialTimeout(network, addr, timeoutToDetour)
			if err == nil {
				log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
				return dc, nil
			}
			log.Debugf("Dial %s to %s failed, try detour: %s", dc.stateDesc(), addr, err)
		}
		dc.setState(stateDetour)
		dc.conn, err = dc.dialDetour(network, addr)
		if err != nil {
			log.Errorf("Dial %s to %s failed", dc.stateDesc(), addr)
			return nil, err
		}
		log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
		return dc, err
	}
}

// Read() implements the function from net.Conn
func (dc *detourConn) Read(b []byte) (n int, err error) {
	conn := dc.getConn()
	if !dc.inState(stateInitial) {
		if n, err = conn.Read(b); err != nil && err != io.EOF {
			log.Tracef("Read from %s %s failed: %s", dc.addr, dc.stateDesc(), err)
			if dc.inState(stateDirect) && blocked(err) {
				// direct route is not reliable even the first read succeeded
				// try again through detour in next dial
				log.Tracef("Seems %s still blocked, add to whitelist so will try detour next time", dc.addr)
				addToWl(dc.addr, false)
			} else if wlTemporarily(dc.addr) {
				log.Tracef("Detoured route is still not reliable for %s, not whitelist it", dc.addr)
				removeFromWl(dc.addr)
			}
			return
		}
		log.Tracef("Read %d bytes from %s %s", n, dc.addr, dc.stateDesc())
		return n, err
	}
	// state will always be settled after first read, safe to clear buffer at end of it
	defer dc.resetBuffer()
	start := time.Now()
	dl := start.Add(timeoutToDetour)
	if !dc.readDeadline.IsZero() && dc.readDeadline.Sub(start) < 2*timeoutToDetour {
		log.Tracef("no time left to test %s, read %s", dc.addr, stateDirect)
		dc.setState(stateDirect)
		return conn.Read(b)
	}
	conn.SetReadDeadline(dl)

	n, err = conn.Read(b)
	conn.SetReadDeadline(dc.readDeadline)
	if err != nil && err != io.EOF {
		ne := fmt.Errorf("Error while read from %s %s, takes %s: %s", dc.addr, dc.stateDesc(), time.Now().Sub(start), err)
		log.Debug(ne)
		if blocked(err) {
			dc.detour(b)
		}
		return n, ne
	}
	log.Tracef("Read %d bytes from %s %s, set state to DIRECT", n, dc.addr, dc.stateDesc())
	dc.setState(stateDirect)
	return n, err
}

// Write() implements the function from net.Conn
func (dc *detourConn) Write(b []byte) (n int, err error) {
	if dc.inState(stateInitial) {
		if n, err = dc.writeToBuffer(b); err != nil {
			return n, fmt.Errorf("Unable to write to local buffer: %s", err)
		}
	}
	if n, err = dc.getConn().Write(b); err != nil {
		log.Debugf("Error while write %d bytes to %s %s: %s", len(b), dc.addr, dc.stateDesc(), err)
		return
	}
	log.Debugf("Wrote %d bytes to %s %s", len(b), dc.addr, dc.stateDesc())
	return
}

// Close() implements the function from net.Conn
func (dc *detourConn) Close() error {
	log.Tracef("Closing %s connection to %s", dc.stateDesc(), dc.addr)
	if wlTemporarily(dc.addr) {
		log.Tracef("no error found till closing, add %s to permanent whitelist", dc.addr)
		addToWl(dc.addr, true)
	}
	return dc.getConn().Close()
}

func (dc *detourConn) LocalAddr() net.Addr {
	return dc.getConn().LocalAddr()
}

func (dc *detourConn) RemoteAddr() net.Addr {
	return dc.getConn().RemoteAddr()
}

func (dc *detourConn) SetDeadline(t time.Time) error {
	dc.SetReadDeadline(t)
	dc.SetWriteDeadline(t)
	return nil
}

func (dc *detourConn) SetReadDeadline(t time.Time) error {
	dc.readDeadline = t
	dc.conn.SetReadDeadline(t)
	return nil
}

func (dc *detourConn) SetWriteDeadline(t time.Time) error {
	dc.writeDeadline = t
	dc.conn.SetWriteDeadline(t)
	return nil
}

func (dc *detourConn) writeToBuffer(b []byte) (n int, err error) {
	dc.muBuf.Lock()
	n, err = dc.buf.Write(b)
	dc.muBuf.Unlock()
	return
}

func (dc *detourConn) resetBuffer() {
	dc.muBuf.Lock()
	dc.buf.Reset()
	dc.muBuf.Unlock()
}

func (dc *detourConn) detour(b []byte) (n int, err error) {
	if err = dc.setupDetour(); err != nil {
		log.Errorf("Error to setup detour: %s", err)
		return
	}
	if _, err = dc.resend(); err != nil {
		err = fmt.Errorf("Error resend buffer to %s: %s", dc.addr, err)
		log.Error(err)
		return
	}
	// should getConn() again as it has changed
	if n, err = dc.getConn().Read(b); err != nil {
		log.Debugf("Read from %s %s still failed: %s", dc.addr, dc.stateDesc(), err)
		return
	}
	dc.setState(stateDetour)
	addToWl(dc.addr, false)
	log.Tracef("Read %d bytes from %s through detour, set state to %s", n, dc.addr, dc.stateDesc())
	return
}

func (dc *detourConn) resend() (int, error) {
	dc.muBuf.Lock()
	b := dc.buf.Bytes()
	dc.muBuf.Unlock()
	if len(b) > 0 {
		n, err := dc.getConn().Write(b)
		log.Tracef("Resend %d buffered bytes to %s, %d sent", len(b), dc.addr, n)
		return n, err
	}
	return 0, nil
}

func (dc *detourConn) setupDetour() error {
	c, err := dc.dialDetour("tcp", dc.addr)
	if err != nil {
		return err
	}
	log.Tracef("Dialed a new detour connection to %s", dc.addr)
	dc.setConn(c)
	return nil
}

func (dc *detourConn) getConn() (c net.Conn) {
	dc.muConn.RLock()
	defer dc.muConn.RUnlock()
	return dc.conn
}

func (dc *detourConn) setConn(c net.Conn) {
	dc.muConn.Lock()
	oldConn := dc.conn
	dc.conn = c
	dc.muConn.Unlock()
	dc.conn.SetReadDeadline(dc.readDeadline)
	dc.conn.SetWriteDeadline(dc.writeDeadline)
	log.Tracef("Replaced connection to %s from direct to detour and closing old one", dc.addr)
	oldConn.Close()
}

func (dc *detourConn) stateDesc() string {
	return statesDesc[atomic.LoadUint32(&dc.state)]
}

func (dc *detourConn) inState(s uint32) bool {
	return atomic.LoadUint32(&dc.state) == s
}

func (dc *detourConn) setState(s uint32) {
	atomic.StoreUint32(&dc.state, s)
}

func blocked(err error) bool {
	if ne, ok := err.(net.Error); ok && ne.Timeout() {
		return true
	}
	if oe, ok := err.(*net.OpError); ok && (oe.Err == syscall.EPIPE || oe.Err == syscall.ECONNRESET) {
		return true
	}
	return false
}

func whitelisted(addr string) bool {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	_, in := whitelist[addr]
	return in
}

func wlTemporarily(addr string) bool {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	return whitelist[addr]
}

func addToWl(addr string, permanent bool) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	whitelist[addr] = permanent
}

func removeFromWl(addr string) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	delete(whitelist, addr)
}
