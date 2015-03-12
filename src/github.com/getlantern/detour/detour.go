/*
Package detour provides a net.Conn interface to dial another dialer
if direct connection is considered blocked
It maintains three states in a connection: initial, direct and detoured
along with a temporary whitelist across connections.
it also add a blocked site to whitelist

The action taken and state transistion in each phase is as follows:
+-------------------------+-----------+-------------+-------------+-------------+-------------+
|                         | no error  |   timeout*  | conn reset/ | content     | other error |
|                         |           |             | dns hijack  | hijack      |             |
+-------------------------+-----------+-------------+-------------+-------------+-------------+
| dial (intial)           | noop      | detour      | detour      | n/a         | noop        |
| first read (intial)     | direct    | detour(buf) | detour(buf) | detour(buf) | noop        |
|                         |           | add to tl   | add to tl   | add to tl   |             |
| follow-up read (direct) | direct    | add to tl   | add to tl   | add to tl   | noop        |
| follow-up read (detour) | noop      | rm from tl  | rm from tl  | rm from tl  | rm from tl  |
| close (direct)          | noop      | n/a         | n/a         | n/a         | n/a         |
| close (detour)          | add to wl | n/a         | n/a         | n/a         | n/a         |
+-------------------------+-----------+-------------+-------------+-------------+-------------+
| next dial/read(in tl)***| noop      | rm from tl  | rm from tl  | rm from tl  | rm from tl  |
| next close(in tl)       | add to wl | n/a         | n/a         | n/a         | n/a         |
+-------------------------+-----------+-------------+-------------+-------------+-------------+
(buf) = resend buffer
tl = temporary whitelist
wl = permanent whitelist
* Operation will time out in TimeoutToDetour in initial state,
and at system default or caller supplied deadline for other states;
but in detoured state, it is considered as timeout if an operation takes longer than TimeoutToDetour.
** DNS hijack is only checked at dial time.
*** Connection is always detoured if the site is in tl or wl.
*/
package detour

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

// if dial or read exceeded this timeout, we consider switch to detour
// The value depends on OS and browser and defaults to 3s
// For Windows XP, find TcpMaxConnectRetransmissions in
// http://support2.microsoft.com/default.aspx?scid=kb;en-us;314053
var TimeoutToDetour = 3 * time.Second

var (
	log = golog.LoggerFor("detour")

	// instance of Detector
	blockDetector atomic.Value
)

func init() {
	blockDetector.Store(detectorByCountry(""))
}

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
	// keep track of bytes sent through direct connection
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

func SetCountry(country string) {
	blockDetector.Store(detectorByCountry(country))
}

func Dialer(dialer dialFunc) dialFunc {
	return func(network, addr string) (conn net.Conn, err error) {
		dc := &detourConn{dialDetour: dialer, network: network, addr: addr}
		if !whitelisted(addr) {
			detector := blockDetector.Load().(*Detector)
			dc.setState(stateInitial)
			dc.conn, err = net.DialTimeout(network, addr, TimeoutToDetour)
			if err == nil {
				if !detector.CheckConn(dc.conn) {
					log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
					return dc, nil
				}
				log.Debugf("Dial %s to %s, dns hijacked, try detour", dc.stateDesc(), addr, err)
			} else if detector.CheckError(err) {
				log.Debugf("Dial %s to %s failed, try detour: %s", dc.stateDesc(), addr, err)
			} else {
				log.Errorf("Dial %s to %s failed: %s", dc.stateDesc(), addr, err)
				return dc, err
			}
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
	detector := blockDetector.Load().(*Detector)
	if !dc.inState(stateInitial) {
		if n, err = conn.Read(b); err != nil {
			if err == io.EOF {
				log.Tracef("Read %d bytes from %s %s, EOF", n, dc.addr, dc.stateDesc())
				return
			}
			log.Tracef("Read from %s %s failed: %s", dc.addr, dc.stateDesc(), err)
			if dc.inState(stateDirect) && detector.CheckError(err) {
				log.Tracef("Seems %s still blocked, add to whitelist so will try detour next time", dc.addr)
				addToWl(dc.addr, false)
			} else if dc.inState(stateDetour) && wlTemporarily(dc.addr) {
				log.Tracef("Detoured route is still not reliable for %s, not whitelist it", dc.addr)
				removeFromWl(dc.addr)
			}
			return
		}
		if dc.inState(stateDirect) && detector.CheckResp(b) {
			log.Tracef("Seems %s still hijacked, add to whitelist so will try detour next time", dc.addr)
			addToWl(dc.addr, false)
		}
		log.Tracef("Read %d bytes from %s %s", n, dc.addr, dc.stateDesc())
		return n, err
	}
	// state will always be settled after first read, safe to clear buffer at end of it
	defer dc.resetBuffer()
	start := time.Now()
	dl := start.Add(TimeoutToDetour)
	if !dc.readDeadline.IsZero() && dc.readDeadline.Sub(start) < 2*TimeoutToDetour {
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
		if detector.CheckError(err) {
			return dc.detour(b)
		}
		return n, ne
	}
	if err == io.EOF {
		log.Tracef("Read %d bytes from %s %s, EOF", n, dc.addr, dc.stateDesc())
		return
	}
	if detector.CheckResp(b) {
		log.Tracef("Read %d bytes from %s %s, content is hijacked, detour", n, dc.addr, dc.stateDesc())
		return dc.detour(b)
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
	log.Tracef("Wrote %d bytes to %s %s", len(b), dc.addr, dc.stateDesc())
	return
}

// Close() implements the function from net.Conn
func (dc *detourConn) Close() error {
	log.Tracef("Closing %s connection to %s", dc.stateDesc(), dc.addr)
	if dc.inState(stateDetour) && wlTemporarily(dc.addr) {
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
		log.Tracef("Resending %d buffered bytes to %s", len(b), dc.addr)
		n, err := dc.getConn().Write(b)
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
