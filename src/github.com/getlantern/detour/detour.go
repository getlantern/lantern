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
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

var TimeoutToConnect = 30 * time.Second

// if DirectAddrCh is set, when a direct connection is closed without any error,
// the connection's remote address (in host:port format) will be send to it
var DirectAddrCh chan string

var (
	log = golog.LoggerFor("detour")
)

type dialFunc func(network, addr string) (net.Conn, error)

type Conn struct {
	muConn sync.RWMutex
	// the underlie connections, access to it should be protected by muConn.
	conns []conn

	// the chan to receive result of any read operation
	chRead chan ioResult
	// the chan to receive result of any write operation
	chWrite chan ioResult

	// keep track of the total bytes read in this connection, atomic
	readBytes uint64

	network, addr string
}

type ioResult struct {
	n    int
	err  error
	conn conn
}

type connType int

const (
	connTypeDirect connType = iota
	connTypeDetour connType = iota
)

var connTypeDesc = []string{
	"direct",
	"detour",
}

type conn interface {
	ConnType() connType
	Valid() bool
	SetInvalid()
	FirstRead(b []byte, ch chan ioResult)
	FollowupRead(b []byte, ch chan ioResult)
	Write(b []byte, ch chan ioResult)
	Close()
}

// Dialer returns a function with same signature of net.Dialer.Dial().
func Dialer(d dialFunc) dialFunc {
	return func(network, addr string) (net.Conn, error) {
		dc := &Conn{network: network, addr: addr, conns: []conn{}, chRead: make(chan ioResult), chWrite: make(chan ioResult)}
		// chAnyConn should be buffered as we may send twice to it but only receive once
		chAnyConn := make(chan conn, 1)
		go func() {
			ch := make(chan conn)
			if !whitelisted(addr) {
				DialDirect(network, addr, ch)
			}
			DialDetour(network, addr, d, ch)
			t := time.NewTimer(TimeoutToConnect)
			for i := 0; i < 2; i++ {
				select {
				case conn := <-ch:
					if dc.anyDataReceived() {
						log.Debugf("Drop a %s connection established too late to %s", connTypeDesc[conn.ConnType()], dc.addr)
						conn.Close()
						return
					}
					dc.muConn.Lock()
					dc.conns = append(dc.conns, conn)
					dc.muConn.Unlock()
					chAnyConn <- conn
				case <-t.C:
					if i == 0 {
						chAnyConn <- nil
					}
					return
				}
			}
		}()
		if anyConn := <-chAnyConn; anyConn != nil {
			return dc, nil
		}
		return nil, fmt.Errorf("Timeout dialing both direct and detour connection to %s", addr)
	}
}

type guardFunc func(conn conn)

func (dc *Conn) runOnValidConn(f guardFunc) (count int) {
	dc.muConn.RLock()
	defer dc.muConn.RUnlock()
	for _, conn := range dc.conns {
		if conn.Valid() {
			f(conn)
			count++
		}
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
		if err != nil {
			continue
		}
		dc.incReadBytes(n)
		dc.runOnValidConn(func(conn conn) {
			if conn.ConnType() != result.conn.ConnType() {
				log.Tracef("Read from %s through %s, set %s as invalid", dc.addr, connTypeDesc[result.conn.ConnType()], connTypeDesc[conn.ConnType()])
				conn.SetInvalid()
				if conn.ConnType() == connTypeDirect {
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

func (dc *Conn) writeNonIdeomponent(b []byte) (count int) {
	dc.muConn.RLock()
	defer dc.muConn.RUnlock()
	log.Tracef("For non ideomponent operation to %s, try write directly first", dc.addr)
	for _, conn := range dc.conns {
		if conn.Valid() && conn.ConnType() == connTypeDirect {
			conn.Write(b, dc.chWrite)
			count++
			return
		}
	}
	log.Tracef("No valid direct connection to %s, write to other (detour)", dc.addr)
	for _, conn := range dc.conns {
		if conn.Valid() {
			conn.Write(b, dc.chWrite)
			count++
			return
		}
	}
	return
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
		n, err = result.n, result.err
		switch result.conn.ConnType() {
		case connTypeDirect:
			if n, err = result.n, result.err; err == nil {
				return
			}
			log.Tracef("Error writing to direct conn to %s, %d attempt: %s", dc.addr, i+1, err)
		case connTypeDetour:
			if n, err = result.n, result.err; err == nil {
				return
			}
			log.Tracef("Error writing to detour conn to %s, %d attempt: %s", dc.addr, i+1, err)
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
