/*
Package detour provides a net.Conn interface which detects blockage
of a site automatically and access it through alternative dialer.

Basically, if a site is not whitelisted, following steps will be taken:
1. Dial proxied dialer a small delay after dialed directly
2. Return to caller if any connection is established
3. Read/write through all connections in parallel
4. Check for blocking in direct connection and closes it if it happens
5. After sucessfully read from a connection, stick with it and close others.
*/
package detour

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

var TimeoutToConnect = 30 * time.Second

// To avoid unnecessarily proxy not-blocked url, detour will dial proxy connection
// after this small delay
var DelayBeforeDetour = 1 * time.Second

// if DirectAddrCh is set, when a direct connection is closed without any error,
// the connection's remote address (in host:port format) will be send to it
var DirectAddrCh chan string

var (
	log = golog.LoggerFor("detour")
)

type dialFunc func(network, addr string) (net.Conn, error)

type Conn struct {
	// the underlie connections, uses buffered channel as ring queue.
	conns chan conn
	// the channel to notify read/write that a new connection is available
	chDetourConn chan conn
	// the chan to notify dialer to dial detour immediately
	chDialDetourNow chan bool

	// the chan to receive result of any read operation
	chRead chan ioResult
	// the chan to receive result of any write operation
	chWrite chan ioResult

	// keep track of the total bytes read from this connection, atomic
	readBytes uint64

	network, addr string

	writeBuffer          *bytes.Buffer
	nonIdempotentRequest bool
}

// The data structure to pass result of io operation back from underlie connection
type ioResult struct {
	// number of bytes read/wrote
	n int
	// io error, if any
	err error
	// the underlie connection itself
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
	Close()
}

func typeOf(c conn) string {
	var connTypeDesc = []string{"direct", "detour"}
	return connTypeDesc[c.ConnType()]
}

// Dialer returns a function with same signature of net.Dialer.Dial().
func Dialer(detourDialer dialFunc) dialFunc {
	return func(network, addr string) (net.Conn, error) {
		dc := &Conn{
			network:         network,
			addr:            addr,
			writeBuffer:     new(bytes.Buffer),
			conns:           make(chan conn, 2),
			chDetourConn:    make(chan conn),
			chRead:          make(chan ioResult),
			chWrite:         make(chan ioResult),
			chDialDetourNow: make(chan bool),
		}
		// use buffered channel, as we may send twice to it but only receive once
		chAnyConn := make(chan bool, 1)
		ch := make(chan conn)
		// dialing sequence
		if whitelisted(addr) {
			DialDetour(network, addr, detourDialer, ch)
		} else {
			go func() {
				DialDirect(network, addr, ch)
				dt := time.NewTimer(DelayBeforeDetour)
				select {
				case <-dt.C:
				case <-dc.chDialDetourNow:
				}
				if dc.anyDataReceived() {
					ch <- nil
				}
				DialDetour(network, addr, detourDialer, ch)
			}()
		}
		// handle dialing result
		go func() {
			t := time.NewTimer(TimeoutToConnect)
			defer t.Stop()
			for i := 0; i < 2; i++ {
				log.Tracef("Waiting for connection to %s", dc.addr)
				select {
				case c := <-ch:
					if c == nil {
						log.Debugf("No new connection to %s remaining, return", dc.addr)
						return
					}
					if i == 0 {
						dc.conns <- c
						chAnyConn <- true
					} else {
						if c.ConnType() == connTypeDirect || dc.anyDataReceived() {
							log.Debugf("%s connection to %s established too late, close it", typeOf(c), dc.addr)
							c.Close()
							return
						}
						log.Tracef("Feed detour connection to %s to read/write op", dc.addr)
						dc.chDetourConn <- c
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
	log.Tracef("Initiate a read request to %s", dc.addr)
	if dc.anyDataReceived() {
		return dc.followupRead(b)
	}
	conn := <-dc.conns
	conn.FirstRead(b, dc.chRead)
	dc.conns <- conn
	log.Tracef("Waiting for response from %s", dc.addr)
	for count := 1; count > 0; count-- {
		select {
		case newConn := <-dc.chDetourConn:
			if dc.nonIdempotentRequest {
				log.Tracef("Not replay nonideompotent request to %s, only add to whitelist", dc.addr)
				AddToWl(dc.addr, false)
				newConn.Close()
				return
			}
			log.Tracef("Got detour connection to %s, replay", dc.addr)
			newConn.Write(dc.writeBuffer.Bytes(), dc.chWrite)
			newConn.FirstRead(b, dc.chRead)
			count++
			// add new connection to connections
			dc.conns <- newConn
		case result := <-dc.chRead:
			log.Tracef("Read back from %s connection", typeOf(result.conn))
			n, err = result.n, result.err
			if err != nil && err != io.EOF {
				log.Tracef("Read from %s connection to %s failed, count=%d: %s", typeOf(result.conn), dc.addr, count, err)
				// skip failed connection
				if count > 1 {
					continue
				}
				switch result.conn.ConnType() {
				case connTypeDirect:
					select {
					// if we haven't dial detour yet, do so now
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
			log.Tracef("Read %d bytes from %s connection to %s", n, typeOf(result.conn), dc.addr)
			dc.incReadBytes(n)
			return n, err
		}
	}
	return
}

// followUpRead is called by Read() if a connection's state already settled
func (dc *Conn) followupRead(b []byte) (n int, err error) {
	conn := <-dc.conns
	conn.FollowupRead(b, dc.chRead)
	dc.conns <- conn
	result := <-dc.chRead
	dc.incReadBytes(result.n)
	return result.n, result.err
}

// Write() implements the function from net.Conn
func (dc *Conn) Write(b []byte) (n int, err error) {
	log.Tracef("Initiate a write request to %s", dc.addr)
	if dc.anyDataReceived() {
		return dc.followUpWrite(b)
	}
	dc.nonIdempotentRequest = isNonIdempotentRequest(b)
	if !dc.nonIdempotentRequest {
		dc.writeBuffer.Write(b)
	}
	conn := <-dc.conns
	conn.Write(b, dc.chWrite)
	dc.conns <- conn
	for count := 1; count > 0; count-- {
		select {
		case result := <-dc.chWrite:
			if n, err = result.n, result.err; err != nil {
				log.Tracef("Error writing %s connection to %s: %s", typeOf(result.conn), dc.addr, err)
				result.conn.Close()
				if count > 0 {
					continue
				}
				return
			}
			log.Tracef("Wrote %d bytes to %s connection to %s", n, typeOf(result.conn), dc.addr)
			return
		}
	}
	return
}

// followUpWrite is called by Write() if a connection's state already settled
func (dc *Conn) followUpWrite(b []byte) (n int, err error) {
	conn := <-dc.conns
	conn.Write(b, dc.chWrite)
	dc.conns <- conn
	result := <-dc.chWrite
	return result.n, result.err
}

// Close() implements the function from net.Conn
func (dc *Conn) Close() error {
	log.Tracef("Closing connection to %s", dc.addr)
	for len(dc.conns) > 0 {
		conn := <-dc.conns
		conn.Close()
	}
	return nil
}

// LocalAddr() implements the function from net.Conn
func (dc *Conn) LocalAddr() net.Addr {
	return nil
}

// RemoteAddr() implements the function from net.Conn
func (dc *Conn) RemoteAddr() net.Addr {
	return nil
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
	return nil
}

// SetWriteDeadline() implements the function from net.Conn
func (dc *Conn) SetWriteDeadline(t time.Time) error {
	return nil
}

var nonIdempotentMethods = [][]byte{
	[]byte("POST "),
	[]byte("PATCH "),
}

// ref section 9.1.2 of https://www.ietf.org/rfc/rfc2616.txt.
// checks against non-idemponent methods actually,
// as we consider the https handshake phase to be idemponent.
func isNonIdempotentRequest(b []byte) bool {
	if len(b) > 4 {
		for _, m := range nonIdempotentMethods {
			if bytes.HasPrefix(b, m) {
				return true
			}
		}
	}
	return false
}
