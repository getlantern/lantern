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
but at system default or caller supplied deadline for other states;
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
	"github.com/getlantern/netx"
)

// if dial or read exceeded this timeout, we consider switch to detour
// The value depends on OS and browser and defaults to 3s
// For Windows XP, find TcpMaxConnectRetransmissions in
// http://support2.microsoft.com/default.aspx?scid=kb;en-us;314053
var TimeoutToDetour = 3 * time.Second

// if DirectAddrCh is set, when a direct connection is closed without any error,
// the connection's remote address (in host:port format) will be send to it
var DirectAddrCh chan string = make(chan string)

var (
	log = golog.LoggerFor("detour")

	// instance of Detector
	blockDetector atomic.Value

	zeroTime time.Time
)

func init() {
	blockDetector.Store(detectorByCountry(""))
}

type dialFunc func(network, addr string) (net.Conn, error)

type Conn struct {
	// keep track of the total bytes read in this connection
	// Keep it at the top to make sure 64-bit alignment, see
	// https://golang.org/pkg/sync/atomic/#pkg-note-BUG
	readBytes int64

	muConn sync.RWMutex
	// the actual connection, will change so protect it
	// can't user atomic.Value as the concrete type may vary
	conn net.Conn

	// don't access directly, use inState() and setState() instead
	state uint32

	// the function to dial detour if the site fails to connect directly
	dialDetour dialFunc

	muLocalBuffer sync.Mutex
	// localBuffer keep track of bytes sent through direct connection
	// in initial state so we can resend them when detour
	localBuffer bytes.Buffer

	network, addr  string
	_readDeadline  atomic.Value
	_writeDeadline atomic.Value
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
			log.Tracef("Attempting direct connection for %v", addr)
			detector := blockDetector.Load().(*Detector)
			dc.setState(stateInitial)
			// always try direct connection first
			dc.conn, err = netx.DialTimeout(network, addr, TimeoutToDetour)
			if err == nil {
				if !detector.DNSPoisoned(dc.conn) {
					log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
					return dc, nil
				}
				log.Debugf("Dial %s to %s, dns hijacked, try detour", dc.stateDesc(), addr)
				if err := dc.conn.Close(); err != nil {
					log.Debugf("Unable to close connection: %v", err)
				}
			} else if detector.TamperingSuspected(err) {
				log.Debugf("Dial %s to %s failed, try detour: %s", dc.stateDesc(), addr, err)
			} else {
				log.Debugf("Dial %s to %s failed: %s", dc.stateDesc(), addr, err)
				return dc, err
			}
		}
		log.Tracef("Detouring %v", addr)
		// if whitelisted or dial directly failed, try detour
		dc.setState(stateDetour)
		dc.conn, err = dc.dialDetour(network, addr)
		if err != nil {
			log.Errorf("Dial %s failed: %s", dc.stateDesc(), err)
			return nil, err
		}
		log.Tracef("Dial %s to %s succeeded", dc.stateDesc(), addr)
		if !whitelisted(addr) {
			log.Tracef("Add %s to whitelist", addr)
			AddToWl(dc.addr, false)
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
	readDeadline := dc.readDeadline()
	if !readDeadline.IsZero() && readDeadline.Sub(start) < 2*TimeoutToDetour {
		log.Tracef("no time left to test %s, read %s", dc.addr, statesDesc[stateDirect])
		dc.setState(stateDirect)
		return dc.countedRead(b)
	}
	// wait for at most TimeoutToDetour to read
	if err := dc.getConn().SetReadDeadline(start.Add(TimeoutToDetour)); err != nil {
		log.Debugf("Unable to set read deadline: %v", err)
	}
	n, err = dc.countedRead(b)
	if err := dc.getConn().SetReadDeadline(readDeadline); err != nil {
		log.Debugf("Unable to set read deadline: %v", err)
	}

	detector := blockDetector.Load().(*Detector)
	if err != nil {
		log.Debugf("Error while read from %s %s: %s", dc.addr, dc.stateDesc(), err)
		if detector.TamperingSuspected(err) {
			// to avoid double submitting, we only resend Idempotent requests
			// but return error directly to application for other requests.
			if dc.isIdempotentRequest() {
				log.Debugf("Detour HTTP GET request to %s", dc.addr)
				return dc.detour(b)
			} else {
				log.Debugf("Not HTTP GET request, add to whitelist")
				AddToWl(dc.addr, false)
			}
		}
		return
	}
	// Hijacked content is usualy encapsulated in one IP packet,
	// so just check it in one read rather than consecutive reads.
	if detector.FakeResponse(b) {
		log.Tracef("Read %d bytes from %s %s, response is hijacked, detour", n, dc.addr, dc.stateDesc())
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
		case dc.inState(stateDirect) && detector.TamperingSuspected(err):
			// to prevent a slow or unstable site from been treated as blocked,
			// we only check first 4K bytes, which roughly equals to the payload of 3 full packets on Ethernet
			if atomic.LoadInt64(&dc.readBytes) <= 4096 {
				log.Tracef("Seems %s still blocked, add to whitelist so will try detour next time", dc.addr)
				AddToWl(dc.addr, false)
			}
		case dc.inState(stateDetour) && wlTemporarily(dc.addr):
			log.Tracef("Detoured route is not reliable for %s, not whitelist it", dc.addr)
			RemoveFromWl(dc.addr)
		}
		return
	}
	// Hijacked content is usualy encapsulated in one IP packet,
	// so just check it in one read rather than consecutive reads.
	if dc.inState(stateDirect) && detector.FakeResponse(b) {
		log.Tracef("%s still content hijacked, add to whitelist so will try detour next time", dc.addr)
		AddToWl(dc.addr, false)
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
	AddToWl(dc.addr, false)
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
	if atomic.LoadInt64(&dc.readBytes) > 0 {
		if dc.inState(stateDetour) && wlTemporarily(dc.addr) {
			log.Tracef("no error found till closing, add %s to permanent whitelist", dc.addr)
			AddToWl(dc.addr, true)
		} else if dc.inState(stateDirect) && !wlTemporarily(dc.addr) {
			log.Tracef("no error found till closing, notify caller that %s can be dialed directly", dc.addr)
			// just fire it, but not blocking if the chan is nil or no reader
			select {
			case DirectAddrCh <- dc.addr:
			default:
			}
		}
	}
	conn := dc.getConn()
	if conn == nil {
		return nil
	}
	return conn.Close()
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
	if err := dc.SetReadDeadline(t); err != nil {
		log.Debugf("Unable to set read deadline: %v", err)
	}
	if err := dc.SetWriteDeadline(t); err != nil {
		log.Debugf("Unable to set write deadline: %v", err)
	}
	return nil
}

// SetReadDeadline() implements the function from net.Conn
func (dc *Conn) SetReadDeadline(t time.Time) error {
	dc._readDeadline.Store(t)
	if err := dc.getConn().SetReadDeadline(t); err != nil {
		log.Debugf("Unable to set read deadline: %v", err)
	}
	return nil
}

func (dc *Conn) readDeadline() time.Time {
	d := dc._readDeadline.Load()
	if d == nil {
		return zeroTime
	}
	return d.(time.Time)
}

// SetWriteDeadline() implements the function from net.Conn
func (dc *Conn) SetWriteDeadline(t time.Time) error {
	dc._writeDeadline.Store(t)
	if err := dc.getConn().SetWriteDeadline(t); err != nil {
		log.Debugf("Unable to set write deadline", err)
	}
	return nil
}

func (dc *Conn) writeDeadline() time.Time {
	d := dc._writeDeadline.Load()
	if d == nil {
		return zeroTime
	}
	return d.(time.Time)
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

var nonIdempotentMethods = [][]byte{
	[]byte("POST "),
	[]byte("PATCH "),
}

// ref section 9.1.2 of https://www.ietf.org/rfc/rfc2616.txt.
// checks against non-idemponent methods actually,
// as we consider the https handshake phase to be idemponent.
func (dc *Conn) isIdempotentRequest() bool {
	dc.muLocalBuffer.Lock()
	defer dc.muLocalBuffer.Unlock()
	b := dc.localBuffer.Bytes()
	if len(b) > 4 {
		for _, m := range nonIdempotentMethods {
			if bytes.HasPrefix(b, m) {
				return false
			}
		}
	}
	return true
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
	if err := dc.conn.SetReadDeadline(dc.readDeadline()); err != nil {
		log.Debugf("Unable to set read deadline: %v", err)
	}
	if err := dc.conn.SetWriteDeadline(dc.writeDeadline()); err != nil {
		log.Debugf("Unable to set write deadline: %v", err)
	}
	log.Tracef("Replaced connection to %s from direct to detour and closing old one", dc.addr)
	if err := oldConn.Close(); err != nil {
		log.Debugf("Unable to close old connection: %v", err)
	}
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
