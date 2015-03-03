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

const (
	stateInitial = iota
	stateDirect  = iota
	stateDetour  = iota
)

const timeDelta = 50 * time.Millisecond

var (
	log             = golog.LoggerFor("detour")
	timeoutToDetour = 1 * time.Second
)

type Dialer func(network, addr string) (net.Conn, error)

type detourConn struct {
	muConn sync.Mutex
	conn   atomic.Value
	state  uint32

	muBuf          sync.Mutex
	buf            bytes.Buffer
	network, addr  string
	detourDeadline time.Time
	readDeadline   time.Time
	writeDeadline  time.Time
}

var detourDialer Dialer

func SetTimeout(t time.Duration) {
	timeoutToDetour = t
}

func SetDetourDialer(d Dialer) {
	detourDialer = d
}
func Dial(network, addr string) (net.Conn, error) {
	dl := time.Now().Add(timeoutToDetour)
	c, err := net.Dial(network, addr)
	if err != nil {
		return c, err
	}
	dc := &detourConn{state: stateInitial, detourDeadline: dl}
	dc.conn.Store(c)
	log.Trace("Dialed a new connection")
	return dc, err
}

// Read() implements the function from net.Conn
func (dc *detourConn) Read(b []byte) (n int, err error) {
	conn := dc.conn.Load().(net.Conn)
	if dc.state != stateInitial {
		log.Tracef("Already settled as %d, read directly", dc.state)
		return conn.Read(b)
	}
	// state will always be settled after first read, safe to clear buffer at end of it
	defer dc.resetBuffer()
	if !dc.readDeadline.IsZero() && dc.readDeadline.Before(dc.detourDeadline.Add(timeDelta)) {
		log.Trace("No time left to try detour, read directly")
		if !atomic.CompareAndSwapUint32(&dc.state, stateInitial, stateDirect) {
			panic("should not occur")
		}
		return conn.Read(b)
	}

	log.Trace("Read directly first")
	conn.SetReadDeadline(dc.detourDeadline)
	if n, err = conn.Read(b); err != nil {
		ne, ok := err.(net.Error)
		if ok && ne.Timeout() {
			log.Trace("Timeout read directly, try detour")
			return dc.detour(b)
		} else if err == io.EOF && n == 0 {
			log.Trace("EOF received with no data, try detour")
			return dc.detour(b)
		} else {
			err = fmt.Errorf("Error while read directly: %s", err)
			// fall through
		}
	}
	if !atomic.CompareAndSwapUint32(&dc.state, stateInitial, stateDirect) {
		panic("should not occur")
	}
	return n, nil
}

// Write() implements the function from net.Conn
func (dc *detourConn) Write(b []byte) (n int, err error) {
	if dc.state == stateInitial {
		if n, err = dc.writeToBuffer(b); err != nil {
			return n, fmt.Errorf("Unable to write local buffer: %s", err)
		}
	}
	return dc.conn.Load().(net.Conn).Write(b)
}

// Close() implements the function from net.Conn
func (dc *detourConn) Close() error {
	return dc.conn.Load().(net.Conn).Close()
}

// LocalAddr() is not implemented
func (dc *detourConn) LocalAddr() net.Addr {
	return dc.conn.Load().(net.Conn).LocalAddr()
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
	conn := dc.conn.Load().(net.Conn)
	if !atomic.CompareAndSwapUint32(&dc.state, stateInitial, stateDetour) {
		panic("should not occur")
	}
	conn.SetReadDeadline(dc.readDeadline)
	if err = dc.setupDetour(); err != nil {
		log.Errorf("Error to setup detour: %s", err)
		return
	}
	if _, err = dc.resend(); err != nil {
		err = fmt.Errorf("Error resend buffered writes: %s", err)
		log.Error(err)
		return
	}
	n, err = dc.conn.Load().(net.Conn).Read(b)
	return
}

func (dc *detourConn) resend() (int, error) {
	dc.muBuf.Lock()
	b := dc.buf.Bytes()
	dc.muBuf.Unlock()
	log.Tracef("Resend %d buffered bytes", len(b))
	return dc.conn.Load().(net.Conn).Write(b)
}

func (dc *detourConn) setupDetour() error {
	c, err := detourDialer(dc.network, dc.addr)
	if err != nil {
		return err
	}
	log.Trace("Dial detour succeeded")
	dc.muConn.Lock()
	oldConn := dc.conn.Load().(net.Conn)
	dc.conn.Store(c)
	dc.muConn.Unlock()
	oldConn.Close()
	return nil
}
