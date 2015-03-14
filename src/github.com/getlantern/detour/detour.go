/*
Package detour provides a net.Conn interface to dial another dialer if a site fails to connect directly.
It maintains three states of a connection: initial, direct and detoured
along with a temporary whitelist across connections.
It also add a blocked site to permanent whitelist.

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

type Conn struct {
	muConn sync.RWMutex
	// the actual connection, will change so protect it
	// can't user atomic.Value as the concrete type may vary
	conn net.Conn

	// don't access directly, use inState() and setState() instead
	state uint32

	// the function to dial detour if the site fails to connect directly
	dialDetour dialFunc

	// keep track of the total bytes read in this connection
	readBytes int64

	muLocalBuffer sync.Mutex
	// localBuffer keep track of bytes sent through direct connection
	// in initial state so we can resend them when detour
	localBuffer bytes.Buffer

	network, addr string
	readDeadline  time.Time
	writeDeadline time.Time
}

const (
	stateInitial = iota
	stateDirect
	stateDetour
)

var statesDesc = []string{
	"initially",
	"directly",
	"detoured",
}

// SetCountry sets the ISO 3166-1 alpha-2 country code
// to load country specific detection rules
func SetCountry(country string) {
	blockDetector.Store(detectorByCountry(country))
}

// Dialer returns a function with same signature of net.Dialer.Dial().
func Dialer(d dialFunc) dialFunc {
	return func(network, addr string) (conn net.Conn, err error) {
		dc := &Conn{dialDetour: d, network: network, addr: addr}
		if !whitelisted(addr) {
			detector := blockDetector.Load().(*Detector)
			dc.setState(stateInitial)
			// always try direct connection first
			dc.conn, err = net.DialTimeout(network, addr, TimeoutToDetour)
			if err == nil {
				if !detector.CheckConn(dc.conn) {
					log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
					return dc, nil
				}
				log.Debugf("Dial %s to %s, dns hijacked, try detour", dc.stateDesc(), addr)
			} else if detector.CheckError(err) {
				log.Debugf("Dial %s to %s failed, try detour: %s", dc.stateDesc(), addr, err)
			} else {
				log.Debugf("Dial %s to %s failed: %s", dc.stateDesc(), addr, err)
				return dc, err
			}
		}
		// if whitelisted or dial directly failed, try detour
		dc.setState(stateDetour)
		dc.conn, err = dc.dialDetour(network, addr)
		if err != nil {
			log.Errorf("Dial %s to %s failed", dc.stateDesc(), addr)
			return nil, err
		}
		log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
		if !whitelisted(addr) {
			log.Tracef("Add %s to whitelist", addr)
			addToWl(dc.addr, false)
		}
		return dc, err
	}
}

// Read() implements the function from net.Conn
func (dc *Conn) Read(b []byte) (n int, err error) {
	if !dc.inState(stateInitial) {
		return dc.followUpRead(b)
	}
	// state will always be settled after first read, safe to clear buffer at end of it
	defer dc.resetLocalBuffer()
	start := time.Now()
	if !dc.readDeadline.IsZero() && dc.readDeadline.Sub(start) < 2*TimeoutToDetour {
		log.Tracef("no time left to test %s, read %s", dc.addr, statesDesc[stateDirect])
		dc.setState(stateDirect)
		return dc.countedRead(b)
	}
	// wait for at most TimeoutToDetour to read
	dc.getConn().SetReadDeadline(start.Add(TimeoutToDetour))
	n, err = dc.countedRead(b)
	dc.getConn().SetReadDeadline(dc.readDeadline)

	detector := blockDetector.Load().(*Detector)
	if err != nil {
		log.Debugf("Error while read from %s %s: %s", dc.addr, dc.stateDesc(), err)
		if detector.CheckError(err) {
			return dc.detour(b)
		}
		return
	}
	// Hijacked content is usualy encapsulated in one IP packet,
	// so just check it in one read rather than consecutive reads.
	if detector.CheckContent(b) {
		log.Tracef("Read %d bytes from %s %s, content is hijacked, detour", n, dc.addr, dc.stateDesc())
		return dc.detour(b)
	}
	log.Tracef("Read %d bytes from %s %s, set state to direct", n, dc.addr, dc.stateDesc())
	dc.setState(stateDirect)
	return
}

// followUpRead is called by Read() if a connection's state already settled
func (dc *Conn) followUpRead(b []byte) (n int, err error) {
	detector := blockDetector.Load().(*Detector)
	if n, err = dc.countedRead(b); err != nil {
		if err == io.EOF {
			log.Tracef("Read %d bytes from %s %s, EOF", n, dc.addr, dc.stateDesc())
			return
		}
		log.Tracef("Read from %s %s failed: %s", dc.addr, dc.stateDesc(), err)
		switch {
		case dc.inState(stateDirect) && detector.CheckError(err):
			log.Tracef("%s still blocked, add to whitelist so will try detour next time", dc.addr)
			addToWl(dc.addr, false)
		case dc.inState(stateDetour) && wlTemporarily(dc.addr):
			log.Tracef("Detoured route is not reliable for %s, not whitelist it", dc.addr)
			removeFromWl(dc.addr)
		}
		return
	}
	// Hijacked content is usualy encapsulated in one IP packet,
	// so just check it in one read rather than consecutive reads.
	if dc.inState(stateDirect) && detector.CheckContent(b) {
		log.Tracef("%s still content hijacked, add to whitelist so will try detour next time", dc.addr)
		addToWl(dc.addr, false)
		return
	}
	log.Tracef("Read %d bytes from %s %s", n, dc.addr, dc.stateDesc())
	return
}

// detour sets up a detoured connection and try read again from it
func (dc *Conn) detour(b []byte) (n int, err error) {
	if err = dc.setupDetour(); err != nil {
		log.Errorf("Error while setup detour: %s", err)
		return
	}
	if _, err = dc.resend(); err != nil {
		err = fmt.Errorf("Error while resend buffer to %s: %s", dc.addr, err)
		log.Error(err)
		return
	}
	dc.setState(stateDetour)
	if n, err = dc.countedRead(b); err != nil {
		log.Debugf("Read from %s %s still failed: %s", dc.addr, dc.stateDesc(), err)
		return
	}
	log.Tracef("Read %d bytes from %s %s, add to whitelist", n, dc.addr, dc.stateDesc())
	addToWl(dc.addr, false)
	return
}

func (dc *Conn) resend() (int, error) {
	dc.muLocalBuffer.Lock()
	// we have to hold the lock until bytes written
	// as Buffer.Bytes is subject to change through Buffer.Write()
	defer dc.muLocalBuffer.Unlock()
	b := dc.localBuffer.Bytes()
	if len(b) == 0 {
		return 0, nil
	}
	log.Tracef("Resending %d bytes from local buffer to %s", len(b), dc.addr)
	n, err := dc.getConn().Write(b)
	return n, err
}

func (dc *Conn) setupDetour() error {
	c, err := dc.dialDetour("tcp", dc.addr)
	if err != nil {
		return err
	}
	log.Tracef("Dialed a new detour connection to %s", dc.addr)
	dc.setConn(c)
	return nil
}

// Write() implements the function from net.Conn
func (dc *Conn) Write(b []byte) (n int, err error) {
	if dc.inState(stateInitial) {
		if n, err = dc.writeLocalBuffer(b); err != nil {
			return n, fmt.Errorf("Unable to write local buffer: %s", err)
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
func (dc *Conn) Close() error {
	log.Tracef("Closing %s connection to %s", dc.stateDesc(), dc.addr)
	if atomic.LoadInt64(&dc.readBytes) > 0 && dc.inState(stateDetour) && wlTemporarily(dc.addr) {
		log.Tracef("no error found till closing, add %s to permanent whitelist", dc.addr)
		addToWl(dc.addr, true)
	}
	return dc.getConn().Close()
}

// LocalAddr() implements the function from net.Conn
func (dc *Conn) LocalAddr() net.Addr {
	return dc.getConn().LocalAddr()
}

// RemoteAddr() implements the function from net.Conn
func (dc *Conn) RemoteAddr() net.Addr {
	return dc.getConn().RemoteAddr()
}

// SetDeadline() implements the function from net.Conn
func (dc *Conn) SetDeadline(t time.Time) error {
	dc.SetReadDeadline(t)
	dc.SetWriteDeadline(t)
	return nil
}

// SetReadDeadline() implements the function from net.Conn
func (dc *Conn) SetReadDeadline(t time.Time) error {
	dc.readDeadline = t
	dc.getConn().SetReadDeadline(t)
	return nil
}

// SetWriteDeadline() implements the function from net.Conn
func (dc *Conn) SetWriteDeadline(t time.Time) error {
	dc.writeDeadline = t
	dc.getConn().SetWriteDeadline(t)
	return nil
}

func (dc *Conn) writeLocalBuffer(b []byte) (n int, err error) {
	dc.muLocalBuffer.Lock()
	n, err = dc.localBuffer.Write(b)
	dc.muLocalBuffer.Unlock()
	return
}

func (dc *Conn) resetLocalBuffer() {
	dc.muLocalBuffer.Lock()
	dc.localBuffer.Reset()
	dc.muLocalBuffer.Unlock()
}

func (dc *Conn) countedRead(b []byte) (n int, err error) {
	n, err = dc.getConn().Read(b)
	atomic.AddInt64(&dc.readBytes, int64(n))
	return
}

func (dc *Conn) getConn() (c net.Conn) {
	dc.muConn.RLock()
	defer dc.muConn.RUnlock()
	return dc.conn
}

func (dc *Conn) setConn(c net.Conn) {
	dc.muConn.Lock()
	oldConn := dc.conn
	dc.conn = c
	dc.muConn.Unlock()
	dc.conn.SetReadDeadline(dc.readDeadline)
	dc.conn.SetWriteDeadline(dc.writeDeadline)
	log.Tracef("Replaced connection to %s from direct to detour and closing old one", dc.addr)
	oldConn.Close()
}

func (dc *Conn) stateDesc() string {
	return statesDesc[atomic.LoadUint32(&dc.state)]
}

func (dc *Conn) inState(s uint32) bool {
	return atomic.LoadUint32(&dc.state) == s
}

func (dc *Conn) setState(s uint32) {
	atomic.StoreUint32(&dc.state, s)
}
