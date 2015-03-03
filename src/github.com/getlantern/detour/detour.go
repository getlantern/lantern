package detour

import (
	"bytes"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("detour")
)

type Dialer func(network, addr string) (net.Conn, error)

type detourConn struct {
	conn atomic.Value

	muBuf         sync.Mutex
	buf           bytes.Buffer
	totalReads    int64
	network, addr string
}

var detourDialer Dialer

func SetDetourDialer(d Dialer) {
	detourDialer = d
}
func Dial(network, addr string) (net.Conn, error) {
	c, err := net.Dial(network, addr)
	dc := &detourConn{}
	dc.conn.Store(c)
	return dc, err
}

// Read() implements the function from net.Conn
func (dc *detourConn) Read(b []byte) (n int, err error) {
	n, err = dc.conn.Load().(net.Conn).Read(b)
	if err == io.EOF && dc.totalReads == 0 {
		log.Debug("EOF encountered, detour")
		if dc.detour() == nil {
			log.Debug("try again with detoured")
			if _, err := dc.resend(); err == nil {
				n, err = dc.conn.Load().(net.Conn).Read(b)
			}
		} else {
			log.Error("Detour failed")
		}
	}
	atomic.AddInt64(&dc.totalReads, int64(n))
	return n, err
}

// Write() implements the function from net.Conn
func (dc *detourConn) Write(b []byte) (n int, err error) {
	dc.muBuf.Lock()
	dc.buf.Write(b)
	dc.muBuf.Unlock()
	return dc.conn.Load().(net.Conn).Write(b)
}

// Close() implements the function from net.Conn
func (dc *detourConn) Close() error {
	return dc.conn.Load().(net.Conn).Close()
}

// LocalAddr() is not implemented
func (dc *detourConn) LocalAddr() net.Addr {
	panic("LocalAddr() not implemented")
}

// RemoteAddr() is not implemented
func (dc *detourConn) RemoteAddr() net.Addr {
	panic("RemoteAddr() not implemented")
}

// SetDeadline() is currently unimplemented.
func (dc *detourConn) SetDeadline(t time.Time) error {
	log.Tracef("SetDeadline not implemented")
	return nil
}

// SetReadDeadline() is currently unimplemented.
func (dc *detourConn) SetReadDeadline(t time.Time) error {
	log.Tracef("SetReadDeadline not implemented")
	return nil
}

// SetWriteDeadline() is currently unimplemented.
func (dc *detourConn) SetWriteDeadline(t time.Time) error {
	log.Tracef("SetWriteDeadline not implemented")
	return nil
}
func (dc *detourConn) resend() (int, error) {
	dc.muBuf.Lock()
	b := dc.buf.Bytes()
	dc.muBuf.Unlock()
	return dc.conn.Load().(net.Conn).Write(b)
}

func (dc *detourConn) detour() error {
	c, err := detourDialer(dc.network, dc.addr)
	if err != nil {
		return err
	}
	dc.conn.Store(c)
	return nil
}
