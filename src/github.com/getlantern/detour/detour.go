/*
Package detour provides a net.Conn interface which detects blockage
of a site automatically and access it through alternative connection.

Basically, if a site is not whitelisted, following steps will be taken:
1. Dial proxied connection (detour) a small delay after dialed directly
2. Return to caller when any connection is established
3. Read/write through all open connections in parallel
4. Check for blockage on direct connection and closes it if it happens
5. If possible, replay operations on detour connection. [1]
6. After sucessfully read from a connection, stick with it and close others.
7. Add those sites failed on direct connection but succeeded on detour ones
   to proxied list, so above steps can be skipped next time. The list can be
   exported and persisted if required.

Blockage can happen at several stages of a connection, what detour can detect are:
1. Connection attempt is blocked (IP blocking / DNS hijack).
   Symptoms can be connection time out / TCP RST / connection refused.
2. Connection made but real data get blocked (DPI).
3. Successfully exchanged a few packets, while follow up packets are blocked. [2]
4. Connection made but get fake response or HTTP redirect to a fixed URL.

[1] Detour will not replay nonidempotent plain HTTP requests, but will add it to
    proxied list to be detoured next time.
[2] Detour can only handle exact 1 successful read followed by failed read,
    which covers most cases in reality.
*/
package detour

import (
	"bytes"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

// If no any connection made after this period, stop dialing and fail
var TimeoutToConnect = 30 * time.Second

// To avoid unnecessarily proxy not-blocked url, detour will dial detour connection
// after this small delay. Set to zero to dial in parallel to not introducing any delay.
var DelayBeforeDetour = 0 * time.Millisecond

// If DirectAddrCh is set, when a direct connection is closed without any error,
// the connection's remote address (in host:port format) will be send to it
var DirectAddrCh = make(chan string)

var (
	log = golog.LoggerFor("detour")
)

// Conn implements an net.Conn interface by utilizing underlie direct and
// detour connections.
type Conn struct {
	// Keeps track of the total bytes read from this connection, atomic
	// Due to https://golang.org/pkg/sync/atomic/#pkg-note-BUG it requires
	// manual alignment. For this, it is best to keep it as the first field
	readBytes uint64

	// The underlie connections, uses buffered channel as ring queue to avoid
	// locking. We have at most 2 connetions so a length of 2 is enough.
	conns chan conn

	// The chan to notify dialer to dial detour immediately
	chDialDetourNow chan bool
	// The channel to notify read/write that a detour connection is available
	chDetourConn chan conn

	// The chan to receive result of any read operation
	chRead chan ioResult
	// The chan to receive result of any write operation
	chWrite chan ioResult

	addr string

	muWriteBuffer sync.RWMutex
	// Keeps written bytes through direct connection to replay it if required.
	writeBuffer *bytes.Buffer
	// Is it a plain HTTP request or not, atomic
	nonidempotentHTTPRequest uint32
}

// The data structure to pass result of io operation back from underlie connection
type ioResult struct {
	// Number of bytes read/wrote
	n int
	// IO error, if any
	err error
	// The underlie connection itself
	conn conn
}

type connType int

const (
	connTypeDirect connType = iota
	connTypeDetour connType = iota
)

type conn interface {
	ConnType() connType
	FirstRead(b []byte, ch chan ioResult)
	FollowupRead(b []byte, ch chan ioResult)
	Write(b []byte, ch chan ioResult)
	Close() error
	Closed() bool
	LocalAddr() net.Addr
	RemoteAddr() net.Addr
}

func typeOf(c conn) string {
	var connTypeDesc = []string{"direct", "detour"}
	return connTypeDesc[c.ConnType()]
}

type dialFunc func(network, addr string) (net.Conn, error)

// Dialer returns a function with same signature of net.Dialer.Dial().
func Dialer(detourDialer dialFunc) func(network, addr string) (net.Conn, error) {
	return func(network, addr string) (net.Conn, error) {
		dc := &Conn{
			addr:            addr,
			writeBuffer:     new(bytes.Buffer),
			conns:           make(chan conn, 2),
			chDetourConn:    make(chan conn),
			chRead:          make(chan ioResult),
			chWrite:         make(chan ioResult),
			chDialDetourNow: make(chan bool),
		}
		// use buffered channel as we may send twice to it but only receive once
		chAnyConn := make(chan bool, 1)
		ch := make(chan conn)

		// dialing sequence
		if whitelisted(addr) {
			dialDetour(network, addr, detourDialer, ch)
		} else {
			go func() {
				dialDirect(network, addr, ch)
				dt := time.NewTimer(DelayBeforeDetour)
				select {
				case <-dt.C:
				case <-dc.chDialDetourNow:
				}
				if dc.anyDataReceived() {
					ch <- nil
					return
				}
				dialDetour(network, addr, detourDialer, ch)
			}()
		}

		// handle dialing result
		go func() {
			t := time.NewTimer(TimeoutToConnect)
			defer t.Stop()
			// At most 2 connections will be made
			for i := 0; i < 2; i++ {
				log.Tracef("Waiting for connection to %s, round %d", dc.addr, i)
				select {
				case c := <-ch:
					if c == nil {
						log.Tracef("No new connection to %s remaining, return", dc.addr)
						return
					}
					// first connection made, pass it back to caller
					if i == 0 {
						dc.conns <- c
						chAnyConn <- true
					} else {
						if c.ConnType() == connTypeDirect {
							// Could happen if direct route is much slower.
							log.Debugf("Direct connection to %s established too late, close it", dc.addr)
							if err := c.Close(); err != nil {
								log.Debugf("Error closing direct connection to %s: %s", dc.addr, err)
							}
							return
						}
						log.Tracef("Feed detour connection to %s to read/write op", dc.addr)
						dc.chDetourConn <- c
						return
					}
				case <-t.C:
					// still no connection made
					chAnyConn <- false
					return
				}
			}
		}()
		// return to caller if any connection available
		if anyConn := <-chAnyConn; anyConn {
			return dc, nil
		}
		return nil, fmt.Errorf("Timeout dialing any connection to %s", addr)
	}
}

func (dc *Conn) anyDataReceived() bool {
	return atomic.LoadUint64(&dc.readBytes) > 0
}

func (dc *Conn) incReadBytes(n int) {
	atomic.AddUint64(&dc.readBytes, uint64(n))
}

// Read() implements the function from net.Conn
func (dc *Conn) Read(b []byte) (n int, err error) {
	if dc.anyDataReceived() {
		return dc.followupRead(b)
	}
	// At initial stage, we only have one connection,
	// but detour connection can be available at anytime.
	if !dc.withValidConn(func(c conn) { c.FirstRead(b, dc.chRead) }) {
		return 0, fmt.Errorf("no connection available to %s", dc.addr)
	}
	for count := 1; count > 0; count-- {
		select {
		case newConn := <-dc.chDetourConn:
			if atomic.LoadUint32(&dc.nonidempotentHTTPRequest) == 1 {
				log.Tracef("Not replay nonidempotent request to %s, only add to whitelist", dc.addr)
				AddToWl(dc.addr, false)
				if err := newConn.Close(); err != nil {
					log.Debugf("Error closing detour connection to %s: %s", dc.addr, err)
				}
				return
			}
			log.Tracef("Got detour connection to %s, replay previous op on it", dc.addr)
			dc.muWriteBuffer.RLock()
			sentBytes := dc.writeBuffer.Bytes()
			dc.muWriteBuffer.RUnlock()
			newConn.Write(sentBytes, dc.chWrite)
			newConn.FirstRead(b, dc.chRead)
			count++
			// add new connection to connections
			dc.conns <- newConn
		case result := <-dc.chRead:
			conn, n, err := result.conn, result.n, result.err
			if err != nil {
				log.Tracef("Read from %s connection to %s failed, closing: %s", typeOf(conn), dc.addr, err)
				if err := conn.Close(); err != nil {
					log.Debugf("Error closing %s connection to %s: %s", typeOf(conn), dc.addr, err)
				}
				// skip failed connection as we have more
				if count > 1 {
					continue
				}
				switch conn.ConnType() {
				case connTypeDirect:
					// if we haven't dial detour yet, do so now
					select {
					case dc.chDialDetourNow <- true:
						count++
					default:
					}
					continue
				case connTypeDetour:
					log.Tracef("Detour connection to %s failed, removing from whitelist", dc.addr)
					RemoveFromWl(dc.addr)
					// no more connections, return directly to avoid dead lock
					return n, err
				}
			}
			log.Tracef("Read %d bytes from %s connection to %s", n, typeOf(conn), dc.addr)
			dc.incReadBytes(n)
			return n, err
		}
	}
	return
}

// followUpRead is called by Read() if a connection's state already settled
func (dc *Conn) followupRead(b []byte) (n int, err error) {
	if !dc.withValidConn(func(c conn) { c.FollowupRead(b, dc.chRead) }) {
		return 0, fmt.Errorf("no connection available to %s", dc.addr)
	}
	result := <-dc.chRead
	dc.incReadBytes(result.n)
	return result.n, result.err
}

// Write() implements the function from net.Conn
func (dc *Conn) Write(b []byte) (n int, err error) {
	if dc.anyDataReceived() {
		return dc.followupWrite(b)
	}
	if isNonidempotentHTTPRequest(b) {
		atomic.StoreUint32(&dc.nonidempotentHTTPRequest, 1)
	} else {
		dc.muWriteBuffer.Lock()
		_, _ = dc.writeBuffer.Write(b)
		dc.muWriteBuffer.Unlock()
	}
	if !dc.withValidConn(func(c conn) { c.Write(b, dc.chWrite) }) {
		return 0, fmt.Errorf("no connection available to %s", dc.addr)
	}

	result := <-dc.chWrite
	if n, err = result.n, result.err; err != nil {
		log.Tracef("Error writing %s connection to %s: %s", typeOf(result.conn), dc.addr, err)
		if err := result.conn.Close(); err != nil {
			log.Debugf("Error closing %s connection to %s: %s", typeOf(result.conn), dc.addr, err)
		}
		return
	}
	log.Tracef("Wrote %d bytes to %s connection to %s", n, typeOf(result.conn), dc.addr)
	return
}

// followupWrite is called by Write() if a connection's state already settled
func (dc *Conn) followupWrite(b []byte) (n int, err error) {
	if !dc.withValidConn(func(c conn) { c.Write(b, dc.chWrite) }) {
		return 0, fmt.Errorf("no connection available to %s", dc.addr)
	}
	result := <-dc.chWrite
	return result.n, result.err
}

// Close implements the function from net.Conn
func (dc *Conn) Close() error {
	log.Tracef("Closing connection to %s", dc.addr)
	for len(dc.conns) > 0 {
		conn := <-dc.conns
		if err := conn.Close(); err != nil {
			log.Debugf("Error closing %s connection to %s: %s", typeOf(conn), dc.addr, err)
		}
	}
	return nil
}

// LocalAddr implements the function from net.Conn
func (dc *Conn) LocalAddr() (addr net.Addr) {
	if !dc.withValidConn(func(c conn) { addr = c.LocalAddr() }) {
		panic("no valid connection to call LocalAddr()")
	}
	return
}

// RemoteAddr implements the function from net.Conn
func (dc *Conn) RemoteAddr() (addr net.Addr) {
	if !dc.withValidConn(func(c conn) { addr = c.RemoteAddr() }) {
		panic("no valid connection to call RemoteAddr()")
	}
	return
}

// SetDeadline implements the function from net.Conn
func (dc *Conn) SetDeadline(t time.Time) error {
	return fmt.Errorf("SetDeadline not implemented")
}

// SetReadDeadline implements the function from net.Conn
func (dc *Conn) SetReadDeadline(t time.Time) error {
	return fmt.Errorf("SetReadDeadline not implemented")
}

// SetWriteDeadline implements the function from net.Conn
func (dc *Conn) SetWriteDeadline(t time.Time) error {
	return fmt.Errorf("SetWriteDeadline not implemented")
}

func (dc *Conn) withValidConn(f func(conn)) bool {
	for i := 0; i < len(dc.conns); i++ {
		select {
		case c := <-dc.conns:
			if c.Closed() {
				log.Tracef("Drain closed %s connection to %s", typeOf(c), dc.addr)
				continue
			}
			f(c)
			dc.conns <- c
			return true
		default:
			break
		}
	}
	return false
}

var nonidempotentMethods = [][]byte{
	[]byte("PUT "),
	[]byte("POST "),
	[]byte("PATCH "),
}

// Ref section 9.1.2 of https://www.ietf.org/rfc/rfc2616.txt.
// We consider the https handshake phase to be idemponent.
func isNonidempotentHTTPRequest(b []byte) bool {
	if len(b) > 4 {
		for _, m := range nonidempotentMethods {
			if bytes.HasPrefix(b, m) {
				return true
			}
		}
	}
	return false
}
