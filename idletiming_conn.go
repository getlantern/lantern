// package idletiming provides mechanisms for adding idle timeouts to net.Conn
// and net.Listener.
package idletiming

import (
	"net"
	"sync/atomic"
	"time"
)

// Conn creates a new net.Conn wrapping the given net.Conn that times out after
// the specified period. Read and Write calls will timeout if they take longer
// than the indicated
//
// idleTimeout specifies how long to wait for inactivity before considering
// connection idle.
//
// onClose is an optional function to call after the connection has been closed,
// whether or not that was due to the connection idling.
func Conn(conn net.Conn, idleTimeout time.Duration, onClose func()) *IdleTimingConn {
	c := &IdleTimingConn{
		conn:             conn,
		idleTimeout:      idleTimeout,
		halfIdleTimeout:  time.Duration(idleTimeout.Nanoseconds() / 2),
		activeCh:         make(chan bool, 10),
		closedCh:         make(chan bool, 10),
		lastActivityTime: int64(time.Now().UnixNano()),
	}

	go func() {
		if onClose != nil {
			defer onClose()
		}

		timer := time.NewTimer(idleTimeout)
		defer timer.Stop()
		for {
			select {
			case <-c.activeCh:
				// We're active, continue
				timer.Reset(idleTimeout)
				atomic.StoreInt64(&c.lastActivityTime, time.Now().UnixNano())
				continue
			case <-timer.C:
				//c.Close()
				return
			case <-c.closedCh:
				c.Close()
				return
			}
		}
	}()

	return c
}

// IdleTimingConn is a net.Conn that wraps another net.Conn and that times out
// if idle for more than idleTimeout.
type IdleTimingConn struct {
	conn             net.Conn
	idleTimeout      time.Duration
	halfIdleTimeout  time.Duration
	readDeadline     *time.Time
	writeDeadline    *time.Time
	activeCh         chan bool
	closedCh         chan bool
	lastActivityTime int64
}

// TimesOutIn returns how much time is left before this connection will time
// out, assuming there is no further activity.
func (c *IdleTimingConn) TimesOutIn() time.Duration {
	return c.TimesOutAt().Sub(time.Now())
}

// TimesOutAt returns the time at which this connection will time out, assuming
// there is no further activity
func (c *IdleTimingConn) TimesOutAt() time.Time {
	return time.Unix(0, c.lastActivityTime).Add(c.idleTimeout)
}

// Read implements the method from io.Reader
func (c *IdleTimingConn) Read(b []byte) (int, error) {
	totalN := 0
	// Continually read while we can, always setting a deadline that's less than
	// our idleTimeout so that we can update our active status before we hit the
	// idleTimeout.
	for {
		maxDeadline := time.Now().Add(c.halfIdleTimeout)
		if c.readDeadline != nil && !maxDeadline.Before(*c.readDeadline) {
			// Caller's deadline is before ours, use it
			c.conn.SetReadDeadline(*c.readDeadline)
			n, err := c.conn.Read(b)
			c.markActive(n)
			totalN = totalN + n
			return totalN, err
		} else {
			// Use our own deadline
			c.conn.SetReadDeadline(maxDeadline)
			n, err := c.conn.Read(b)
			c.markActive(n)
			totalN = totalN + n
			timedOut := isTimeout(err)
			if timedOut {
				// Ignore timeouts when using deadline based on IdleTimeout
				err = nil
			}
			if n == 0 || !timedOut {
				return totalN, err
			}
			b = b[n:]
		}
	}
}

// Write implements the method from io.Reader
func (c *IdleTimingConn) Write(b []byte) (int, error) {
	totalN := 0
	// Continually write while we can, always setting a deadline that's less
	// than our idleTimeout so that we can update our active status before we
	// hit the idleTimeout.
	for {
		maxDeadline := time.Now().Add(c.halfIdleTimeout)
		if c.writeDeadline != nil && !maxDeadline.Before(*c.writeDeadline) {
			// Caller's deadline is before ours, use it
			c.conn.SetWriteDeadline(*c.writeDeadline)
			n, err := c.conn.Write(b)
			c.markActive(n)
			totalN = totalN + n
			return totalN, err
		} else {
			// Use our own deadline
			c.conn.SetWriteDeadline(maxDeadline)
			n, err := c.conn.Write(b)
			c.markActive(n)
			totalN = totalN + n
			timedOut := isTimeout(err)
			if timedOut {
				// Ignore timeouts when using deadline based on IdleTimeout
				err = nil
			}
			if n == 0 || !timedOut {
				return totalN, err
			}
			b = b[n:]
		}
	}
}

func (c *IdleTimingConn) Close() error {
	c.closedCh <- true
	return c.conn.Close()
}

func (c *IdleTimingConn) LocalAddr() net.Addr {
	return c.conn.LocalAddr()
}

func (c *IdleTimingConn) RemoteAddr() net.Addr {
	return c.conn.RemoteAddr()
}

func (c *IdleTimingConn) SetDeadline(t time.Time) error {
	c.SetReadDeadline(t)
	c.SetWriteDeadline(t)
	return nil
}

func (c *IdleTimingConn) SetReadDeadline(t time.Time) error {
	c.readDeadline = &t
	return nil
}

func (c *IdleTimingConn) SetWriteDeadline(t time.Time) error {
	c.writeDeadline = &t
	return nil
}

func (c *IdleTimingConn) markActive(n int) bool {
	if n > 0 {
		c.activeCh <- true
		return true
	} else {
		return false
	}
}

func isTimeout(err error) bool {
	if netErr, ok := err.(net.Error); ok {
		return netErr.Timeout()
	}
	return false
}
