// package idletiming provides mechanisms for adding idle timeouts to net.Conn
// and net.Listener.
package idletiming

import (
	"errors"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

var (
	epoch = time.Unix(0, 0)
	log   = golog.LoggerFor("idletiming")

	// ErrIdled is return when attempting to use a network connection that was
	// closed because of idling.
	ErrIdled = errors.New("Use of idled network connection")
)

// Conn creates a new net.Conn wrapping the given net.Conn that times out after
// the specified period. Once a connection has timed out, any pending reads or
// writes will return io.EOF and the underlying connection will be closed.
//
// idleTimeout specifies how long to wait for inactivity before considering
// connection idle.
//
// If onIdle is specified, it will be called to indicate when the connection has
// idled and been closed.
func Conn(conn net.Conn, idleTimeout time.Duration, onIdle func()) *IdleTimingConn {
	c := &IdleTimingConn{
		conn:             conn,
		idleTimeout:      idleTimeout,
		halfIdleTimeout:  time.Duration(idleTimeout.Nanoseconds() / 2),
		activeCh:         make(chan bool, 1),
		closedCh:         make(chan bool, 1),
		lastActivityTime: int64(time.Now().UnixNano()),
	}

	go func() {
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
				c.Close()
				if onIdle != nil {
					onIdle()
				}
				return
			case <-c.closedCh:
				return
			}
		}
	}()

	return c
}

// IdleTimingConn is a net.Conn that wraps another net.Conn and that times out
// if idle for more than idleTimeout.
type IdleTimingConn struct {
	// Keep them at the top to make sure 64-bit alignment, see
	// https://golang.org/pkg/sync/atomic/#pkg-note-BUG
	readDeadline     int64
	writeDeadline    int64
	lastActivityTime int64

	conn             net.Conn
	idleTimeout      time.Duration
	halfIdleTimeout  time.Duration
	activeCh         chan bool
	closedCh         chan bool
	closeMutex       sync.RWMutex // prevents Close() from interfering with io operations
	closed           bool
	hasReadAfterIdle int32
}

// TimesOutIn returns how much time is left before this connection will time
// out, assuming there is no further activity.
func (c *IdleTimingConn) TimesOutIn() time.Duration {
	return c.TimesOutAt().Sub(time.Now())
}

// TimesOutAt returns the time at which this connection will time out, assuming
// there is no further activity
func (c *IdleTimingConn) TimesOutAt() time.Time {
	return time.Unix(0, atomic.LoadInt64(&c.lastActivityTime)).Add(c.idleTimeout)
}

// Read implements the method from io.Reader
func (c *IdleTimingConn) Read(b []byte) (int, error) {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	if err := c.checkClosedFirstTime(&c.hasReadAfterIdle, io.EOF); err != nil {
		return 0, err
	}

	totalN := 0
	readDeadline := time.Unix(0, atomic.LoadInt64(&c.readDeadline))

	// Continually read while we can, always setting a deadline that's less than
	// our idleTimeout so that we can update our active status before we hit the
	// idleTimeout.
	for {
		maxDeadline := time.Now().Add(c.halfIdleTimeout)
		if readDeadline != epoch && !maxDeadline.Before(readDeadline) {
			// Caller's deadline is before ours, use it
			if err := c.conn.SetReadDeadline(readDeadline); err != nil {
				log.Tracef("Unable to set read deadline: %v", err)
			}
			n, err := c.conn.Read(b)
			c.markActive(n)
			totalN = totalN + n
			return totalN, err
		} else {
			// Use our own deadline
			if err := c.conn.SetReadDeadline(maxDeadline); err != nil {
				log.Tracef("Unable to set read deadline: %v", err)
			}
			n, err := c.conn.Read(b)
			c.markActive(n)
			totalN = totalN + n
			hitMaxDeadline := isTimeout(err) && !time.Now().Before(maxDeadline)
			if hitMaxDeadline {
				// Ignore timeouts when encountering deadline based on
				// IdleTimeout
				err = nil
			}
			if n == 0 || !hitMaxDeadline {
				return totalN, err
			}
			b = b[n:]
		}
	}
}

// Write implements the method from io.Reader
func (c *IdleTimingConn) Write(b []byte) (int, error) {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	if err := c.checkClosed(); err != nil {
		return 0, err
	}

	totalN := 0
	writeDeadline := time.Unix(0, atomic.LoadInt64(&c.writeDeadline))

	// Continually write while we can, always setting a deadline that's less
	// than our idleTimeout so that we can update our active status before we
	// hit the idleTimeout.
	for {
		maxDeadline := time.Now().Add(c.halfIdleTimeout)
		if writeDeadline != epoch && !maxDeadline.Before(writeDeadline) {
			// Caller's deadline is before ours, use it
			if err := c.conn.SetWriteDeadline(writeDeadline); err != nil {
				log.Tracef("Unable to set write deadline: %v", err)
			}
			n, err := c.conn.Write(b)
			c.markActive(n)
			totalN = totalN + n
			return totalN, err
		} else {
			// Use our own deadline
			if err := c.conn.SetWriteDeadline(maxDeadline); err != nil {
				log.Tracef("Unable to set write deadline: %v", err)
			}
			n, err := c.conn.Write(b)
			c.markActive(n)
			totalN = totalN + n
			hitMaxDeadline := isTimeout(err) && !time.Now().Before(maxDeadline)
			if hitMaxDeadline {
				// Ignore timeouts when encountering deadline based on
				// IdleTimeout
				err = nil
			}
			if n == 0 || !hitMaxDeadline {
				return totalN, err
			}
			b = b[n:]
		}
	}
}

// Close this IdleTimingConn. This will close the underlying net.Conn as well,
// returning the error from calling its Close method.
func (c *IdleTimingConn) Close() error {
	c.closeMutex.Lock()
	defer c.closeMutex.Unlock()

	if err := c.checkClosed(); err != nil {
		return err
	}

	c.closed = true

	select {
	case c.closedCh <- true:
		// close accepted
	default:
		// already closing, ignore
	}
	return c.conn.Close()
}

func (c *IdleTimingConn) LocalAddr() net.Addr {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	return c.conn.LocalAddr()
}

func (c *IdleTimingConn) RemoteAddr() net.Addr {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	return c.conn.RemoteAddr()
}

func (c *IdleTimingConn) SetDeadline(t time.Time) error {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	if err := c.checkClosed(); err != nil {
		return err
	}

	if err := c.SetReadDeadline(t); err != nil {
		log.Tracef("Unable to set read deadline: %v", err)
	}
	if err := c.SetWriteDeadline(t); err != nil {
		log.Tracef("Unable to set write deadline: %v", err)
	}
	return nil
}

func (c *IdleTimingConn) SetReadDeadline(t time.Time) error {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	if err := c.checkClosed(); err != nil {
		return err
	}

	atomic.StoreInt64(&c.readDeadline, t.UnixNano())
	return nil
}

func (c *IdleTimingConn) SetWriteDeadline(t time.Time) error {
	c.closeMutex.RLock()
	defer c.closeMutex.RUnlock()

	if err := c.checkClosed(); err != nil {
		return err
	}

	atomic.StoreInt64(&c.writeDeadline, t.UnixNano())
	return nil
}

func (c *IdleTimingConn) markActive(n int) bool {
	if n > 0 {
		select {
		case c.activeCh <- true:
			// ok
		default:
			// still waiting to process previous markActive
		}
		return true
	}
	return false
}

func (c *IdleTimingConn) checkClosed() error {
	return c.checkClosedFirstTime(nil, nil)
}

func (c *IdleTimingConn) checkClosedFirstTime(hasDone *int32, firstTimeError error) error {
	if c.closed {
		if hasDone != nil && atomic.CompareAndSwapInt32(hasDone, 0, 1) {
			return firstTimeError
		}
		return ErrIdled
	}
	return nil
}

func isTimeout(err error) bool {
	if netErr, ok := err.(net.Error); ok {
		return netErr.Timeout()
	}
	return false
}
