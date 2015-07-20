// package bytecounting provides mechanisms for counting bytes read/written on
// net.Conn and net.Listener.
package bytecounting

import (
	"net"
	"time"
)

// Conn is a net.Conn that wraps another net.Conn and counts bytes read/written
// by reporting them to callback functions.
type Conn struct {
	Orig    net.Conn
	OnRead  func(bytes int64)
	OnWrite func(bytes int64)
}

// Read implements the method from io.Reader
func (c *Conn) Read(b []byte) (int, error) {
	n, err := c.Orig.Read(b)
	if c.OnRead != nil {
		c.OnRead(int64(n))
	}
	return n, err
}

// Write implements the method from io.Reader
func (c *Conn) Write(b []byte) (int, error) {
	n, err := c.Orig.Write(b)
	if c.OnWrite != nil {
		c.OnWrite(int64(n))
	}
	return n, err
}

func (c *Conn) Close() error {
	return c.Orig.Close()
}

func (c *Conn) LocalAddr() net.Addr {
	return c.Orig.LocalAddr()
}

func (c *Conn) RemoteAddr() net.Addr {
	return c.Orig.RemoteAddr()
}

func (c *Conn) SetDeadline(t time.Time) error {
	return c.Orig.SetDeadline(t)
}

func (c *Conn) SetReadDeadline(t time.Time) error {
	return c.Orig.SetReadDeadline(t)
}

func (c *Conn) SetWriteDeadline(t time.Time) error {
	return c.Orig.SetWriteDeadline(t)
}
