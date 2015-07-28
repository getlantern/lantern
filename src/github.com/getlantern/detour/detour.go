/*
Package detour provides a net.Conn interface which detects blockage
of a site automatically and try to access it through alternative dialer.

Basically, if a site is not whitelisted, it has follow steps:
1. Dial in parallel
2. Return to caller if any connection is established
3. Read/write to all connections
4. After sucessfully read from a connection, stick with it and close others.
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

	// the chan to receive result of any read operation
	chRead chan ioResult
	// the chan to receive result of any write operation
	chWrite chan ioResult

	// keep track of the total bytes read in this connection, atomic
	readBytes uint64

	network, addr string
}

// The data structure to pass result of io operation back from underlie connection
type ioResult struct {
	// number of bytes processed
	n int
	// io error, if any
	err error
	// the underlie connection that actually do the io operation
	conn conn
}

type connType int

const (
	connTypeDirect connType = iota
	connTypeDetour connType = iota
)

type conn interface {
	ConnType() connType
	Valid() bool
	SetInvalid()
	FirstRead(b []byte, ch chan ioResult)
	FollowupRead(b []byte, ch chan ioResult)
	Write(b []byte, ch chan ioResult)
	Close()
}

func typeOf(c conn) string {
	var connTypeDesc = []string{
		"direct",
		"detour",
	}
	return connTypeDesc[c.ConnType()]
}

// Dialer returns a function with same signature of net.Dialer.Dial().
func Dialer(df dialFunc) dialFunc {
	return func(network, addr string) (net.Conn, error) {
		dc := &Conn{network: network, addr: addr, conns: make(chan conn, 2), chRead: make(chan ioResult), chWrite: make(chan ioResult)}
		// buffered channel, as we may send twice to it but only receive once
		chAnyConn := make(chan conn, 1)
		ch := make(chan conn)
		go func() {
			if !whitelisted(addr) {
				DialDirect(network, addr, ch)
				time.Sleep(DelayBeforeDetour)
			}
			DialDetour(network, addr, df, ch)
		}()
		go func() {
			t := time.NewTimer(TimeoutToConnect)
			for i := 0; i < 2; i++ {
				select {
				case conn := <-ch:
					if dc.anyDataReceived() {
						log.Debugf("Drop a %s connection established too late to %s", typeOf(conn), dc.addr)
						conn.Close()
						return
					}
					dc.conns <- conn
					chAnyConn <- conn
				case <-t.C:
					if i == 0 {
						chAnyConn <- nil
					}
					return
				}
			}
		}()
		// return to caller if any connection available
		if anyConn := <-chAnyConn; anyConn != nil {
			return dc, nil
		}
		return nil, fmt.Errorf("Timeout dialing both direct and detour connection to %s", addr)
	}
}

func (dc *Conn) runOnValidConn(f func(conn)) (count int) {
	for i := 0; i < len(dc.conns); i++ {
		conn := <-dc.conns
		if !conn.Valid() {
			conn.Close()
			continue
		}
		f(conn)
		dc.conns <- conn
		count++
	}
	return
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
	count := dc.runOnValidConn(func(conn conn) {
		conn.FirstRead(b, dc.chRead)
	})
	for i := 0; i < count; i++ {
		result := <-dc.chRead
		n, err = result.n, result.err
		if err != nil && err != io.EOF {
			log.Tracef("Read from %s through %s failed, set as invalid: %s", dc.addr, typeOf(result.conn), err)
			result.conn.SetInvalid()
			// skip failed connection
			continue
		}
		log.Tracef("Read %d bytes from %s connection to %s", n, typeOf(result.conn), dc.addr)
		dc.incReadBytes(n)
		dc.runOnValidConn(func(c conn) {
			if c != result.conn {
				log.Tracef("Set %s connection to %s as invalid", typeOf(c), dc.addr)
				c.SetInvalid()
				// direct connection failed
				if c.ConnType() == connTypeDirect {
					log.Tracef("Add %s to whitelist", dc.addr)
					AddToWl(dc.addr, false)
				}
			}
		})
		return
	}
	return
}

// followUpRead is called by Read() if a connection's state already settled
func (dc *Conn) followupRead(b []byte) (n int, err error) {
	dc.runOnValidConn(func(conn conn) {
		conn.FollowupRead(b, dc.chRead)
	})
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
	var count int
	if isNonIdempotentRequest(b) {
		count = dc.writeNonIdeomponent(b)
	} else {
		count = dc.runOnValidConn(func(conn conn) {
			conn.Write(b, dc.chWrite)
		})
	}
	for i := 0; i < count; i++ {
		result := <-dc.chWrite
		if n, err = result.n, result.err; err != nil {
			log.Tracef("Error writing %s connection to %s, %d attempt: %s", typeOf(result.conn), dc.addr, i+1, err)
			continue
		}
		log.Tracef("Wrote %d bytes to %s connection to %s", n, typeOf(result.conn), dc.addr)
		return
	}
	return
}

func (dc *Conn) writeNonIdeomponent(b []byte) (count int) {
	log.Tracef("For non ideomponent operation to %s, try write directly first", dc.addr)
	for i := 0; i < len(dc.conns); i++ {
		conn := <-dc.conns
		if conn.Valid() && conn.ConnType() == connTypeDirect {
			conn.Write(b, dc.chWrite)
			dc.conns <- conn
			count++
			return
		}
	}
	log.Tracef("No valid direct connection to %s, write to other (detour)", dc.addr)
	for i := 0; i < len(dc.conns); i++ {
		conn := <-dc.conns
		if conn.Valid() {
			conn.Write(b, dc.chWrite)
			dc.conns <- conn
			count++
			return
		}
	}
	return
}

// followUpWrite is called by Write() if a connection's state already settled
func (dc *Conn) followUpWrite(b []byte) (n int, err error) {
	dc.runOnValidConn(func(conn conn) {
		conn.Write(b, dc.chWrite)
	})
	result := <-dc.chWrite
	return result.n, result.err
}

// Close() implements the function from net.Conn
func (dc *Conn) Close() error {
	log.Tracef("Closing connection to %s", dc.addr)
	dc.runOnValidConn(func(conn conn) {
		conn.Close()
	})
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
	dc.SetReadDeadline(t)
	dc.SetWriteDeadline(t)
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
