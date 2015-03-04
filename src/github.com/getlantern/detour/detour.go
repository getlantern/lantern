package detour

import (
	"bytes"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/getlantern/golog"
)

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

const timeDelta = 50 * time.Millisecond

var (
	log             = golog.LoggerFor("detour")
	timeoutToDetour = 5 * time.Second
	muWhitelist     sync.RWMutex
	whitelist       = make(map[string]bool)
)

type Dialer func(network, addr string) (net.Conn, error)

type detourConn struct {
	muConn sync.RWMutex
	conn   net.Conn
	state  uint32

	dialDetour Dialer

	muBuf         sync.Mutex
	buf           bytes.Buffer
	network, addr string
	readDeadline  time.Time
	writeDeadline time.Time
}

func SetTimeout(t time.Duration) {
	timeoutToDetour = t
}

func DetourDialer(dialer Dialer) Dialer {
	return func(network, addr string) (conn net.Conn, err error) {
		dc := &detourConn{dialDetour: dialer, network: network, addr: addr}
		if in, _ := inWhitelist(addr); !in {
			dc.state = stateInitial
			dc.conn, err = net.Dial(network, addr)
			if err == nil {
				log.Tracef("Dialed a new %s connection to %s", dc.stateDesc(), addr)
				return dc, nil
			}
			log.Debugf("Dial %s to %s failed, try detour", dc.stateDesc(), addr)
		}
		dc.state = stateDetour
		dc.conn, err = dc.dialDetour(network, addr)
		if err != nil {
			log.Errorf("Dial %s to %s failed", dc.stateDesc(), addr)
			return nil, err
		}
		log.Tracef("Dialed a new %s connection to %s", dc.stateDesc(), addr)
		return dc, err
	}
}

// Read() implements the function from net.Conn
func (dc *detourConn) Read(b []byte) (n int, err error) {
	conn := dc.getConn()
	if dc.state != stateInitial {
		if n, err = conn.Read(b); err != nil {
			log.Debugf("Read from %s %s failed: %s", dc.addr, dc.stateDesc(), err)
			if dc.state != stateDetour {
				log.Debugf("Add %s to white list temporarily", dc.addr)
				addToWhitelist(dc.addr, false)
			}
			return
		}
		log.Tracef("Read %d bytes from %s %s", n, dc.addr, dc.stateDesc())
		return
	}
	if in, _ := inWhitelist(dc.addr); in {
		log.Tracef("%s in white list, detour", dc.addr)
		return dc.detour(b)
	}
	// state will always be settled after first read, safe to clear buffer at end of it
	defer dc.resetBuffer()
	dl := time.Now().Add(timeoutToDetour)
	if !dc.readDeadline.IsZero() && dc.readDeadline.Before(dl.Add(timeDelta)) {
		atomic.CompareAndSwapUint32(&dc.state, stateInitial, stateDirect)
		n, err = conn.Read(b)
		log.Tracef("No time left to detour, read %d bytes from %s directly, err=%s", n, dc.addr, err)
		return
	}

	log.Tracef("Read from %s directly first", dc.addr)
	conn.SetReadDeadline(dl)
	if n, err = conn.Read(b); err != nil {
		ne, ok := err.(net.Error)
		if ok && ne.Timeout() {
			log.Tracef("Timeout read directly from %s, try detour", dc.addr)
			return dc.detour(b)
		} else if oe, ok := err.(*net.OpError); ok && oe.Err == syscall.ECONNRESET {
			log.Tracef("RST received from %s, try detour", dc.addr)
			return dc.detour(b)
			/*} else if err == io.EOF && n == 0 {
			log.Tracef("EOF received with no data from %s, try detour", dc.addr)
			return dc.detour(b)*/
		} else {
			err = fmt.Errorf("Error while read from %s directly: %s", dc.addr, err)
			log.Error(err)
			return
		}
	}
	atomic.CompareAndSwapUint32(&dc.state, stateInitial, stateDirect)
	log.Tracef("Read %d bytes from %s directly, set state to %s", n, dc.addr, dc.stateDesc())
	return n, nil
}

// Write() implements the function from net.Conn
func (dc *detourConn) Write(b []byte) (n int, err error) {
	if dc.state == stateInitial {
		if n, err = dc.writeToBuffer(b); err != nil {
			return n, fmt.Errorf("Unable to write to local buffer: %s", err)
		}
	}
	if n, err = dc.getConn().Write(b); err != nil {
		log.Debugf("Write %d bytes to %s %s failed: %s", len(b), dc.addr, dc.stateDesc(), err)
		if dc.state != stateDetour {
			log.Debugf("Add %s to white list temporarily", dc.addr)
			addToWhitelist(dc.addr, false)
		}
	}
	return
}

// Close() implements the function from net.Conn
func (dc *detourConn) Close() error {
	log.Tracef("Closing connection to %s", dc.addr)
	return dc.getConn().Close()
}

// LocalAddr() is not implemented
func (dc *detourConn) LocalAddr() net.Addr {
	return dc.getConn().LocalAddr()
}

// RemoteAddr() is not implemented
func (dc *detourConn) RemoteAddr() net.Addr {
	panic("RemoteAddr() not implemented")
}

func (dc *detourConn) SetDeadline(t time.Time) error {
	dc.SetReadDeadline(t)
	dc.SetWriteDeadline(t)
	return nil
}

func (dc *detourConn) SetReadDeadline(t time.Time) error {
	dc.readDeadline = t
	return nil
}

func (dc *detourConn) SetWriteDeadline(t time.Time) error {
	dc.writeDeadline = t
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
	conn := dc.getConn()
	conn.SetReadDeadline(dc.readDeadline)
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
		log.Debugf("Read from %s through detour failed: %s", dc.addr, err)
		return
	}
	atomic.CompareAndSwapUint32(&dc.state, stateInitial, stateDetour)
	addToWhitelist(dc.addr, true)
	log.Tracef("Read %d bytes from %s through detour, set state to %s", n, dc.addr, dc.stateDesc())
	return
}

func (dc *detourConn) resend() (int, error) {
	dc.muBuf.Lock()
	b := dc.buf.Bytes()
	dc.muBuf.Unlock()
	n, err := dc.getConn().Write(b)
	log.Tracef("Resend %d buffered bytes to %s, %d sent", len(b), dc.addr, n)
	return n, err
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
	log.Tracef("Replaced connection to %s from direct to detour and closing old one", dc.addr)
	oldConn.Close()
}

func (dc *detourConn) stateDesc() string {
	return statesDesc[dc.state]
}

func inWhitelist(addr string) (in bool, permanent bool) {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	permanent, in = whitelist[addr]
	return
}

func addToWhitelist(addr string, permanent bool) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	whitelist[addr] = permanent
}

func removeFromWhitelist(addr string) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	delete(whitelist, addr)
}
