package idletiming

import (
	"io"
	"io/ioutil"
	"net"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/stretchr/testify/assert"
)

var (
	msg = []byte("HelloThere")

	dataLoops = 10

	clientTimeout                 = 25 * time.Millisecond
	serverTimeout                 = 10 * clientTimeout
	slightlyLessThanClientTimeout = time.Duration(int64(float64(clientTimeout.Nanoseconds()) * 0.5))
	slightlyMoreThanClientTimeout = time.Duration(int64(float64(clientTimeout.Nanoseconds()) * 1.5))
)

func TestWrite(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	listenerIdled := int32(0)
	connIdled := int32(0)

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	addr := l.Addr().String()
	il := Listener(l, serverTimeout, func(conn net.Conn) {
		atomic.StoreInt32(&listenerIdled, 1)
	})
	defer func() {
		if err := il.Close(); err != nil {
			t.Errorf("Unable to close listener: %v", err)
		}
		time.Sleep(1 * time.Second)
		err = fdc.AssertDelta(0)
		if err != nil {
			t.Errorf("File descriptors didn't return to original: %s", err)
		}
	}()

	go func() {
		conn, err := il.Accept()
		if err != nil {
			t.Fatalf("Unable to accept: %s", err)
		}
		go func() {
			// Discard data
			if _, err := io.Copy(ioutil.Discard, conn); err != nil {
				t.Fatalf("Unable to discard data: %v", err)
			}
		}()
	}()

	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Unable to dial %s: %s", addr, err)
	}

	conn = &slowConn{orig: conn, targetDuration: slightlyLessThanClientTimeout}

	c := Conn(conn, clientTimeout, func() {
		atomic.StoreInt32(&connIdled, 1)
	})

	// Write messages
	for i := 0; i < dataLoops; i++ {
		n, err := c.Write(msg)
		if err != nil || n != len(msg) {
			t.Fatalf("Problem writing.  n: %d  err: %s", n, err)
		}
	}

	// Now write msg with a really short deadline
	if err := c.SetWriteDeadline(time.Now().Add(1 * time.Nanosecond)); err != nil {
		t.Fatalf("Unable to set write deadline: %v", err)
	}
	_, err = c.Write(msg)
	if netErr, ok := err.(net.Error); ok {
		if !netErr.Timeout() {
			t.Fatalf("Short deadline should have resulted in Timeout, but didn't: %s", err)
		}
	} else {
		t.Fatalf("Short deadline should have resulted in Timeout, but didn't: %s", err)
	}

	time.Sleep(slightlyMoreThanClientTimeout)
	if atomic.LoadInt32(&connIdled) == 0 {
		t.Errorf("Conn failed to idle!")
	}

	time.Sleep(slightlyMoreThanClientTimeout)
	_, err = c.Write(make([]byte, 10))
	assert.Equal(t, ErrIdled, err, "Write after idle should return ErrIdled")

	connTimesOutIn := c.TimesOutIn()
	if connTimesOutIn > 0 {
		t.Errorf("TimesOutIn returned bad value, should have been negative, but was: %s", connTimesOutIn)
	}

	time.Sleep(9 * slightlyMoreThanClientTimeout)
	if atomic.LoadInt32(&listenerIdled) == 0 {
		t.Errorf("Listener failed to idle!")
	}
}

func TestRead(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	connIdled := int32(0)
	listenerIdled := int32(0)

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	il := Listener(l, serverTimeout, func(conn net.Conn) {
		atomic.StoreInt32(&listenerIdled, 1)
	})
	defer func() {
		if err := il.Close(); err != nil {
			t.Fatalf("Unable to close listener: %v", err)
		}
		time.Sleep(1 * time.Second)
		err = fdc.AssertDelta(0)
		if err != nil {
			t.Errorf("File descriptors didn't return to original: %s", err)
		}
	}()

	addr := l.Addr().String()

	go func() {
		conn, err := il.Accept()
		if err != nil {
			t.Fatalf("Unable to accept: %s", err)
		}
		go func() {
			// Feed data
			for i := 0; i < dataLoops; i++ {
				_, err := conn.Write(msg)
				if err != nil {
					return
				}
			}
		}()
	}()

	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Unable to dial %s: %s", addr, err)
	}

	conn = &slowConn{orig: conn, targetDuration: slightlyLessThanClientTimeout}

	c := Conn(conn, clientTimeout, func() {
		atomic.StoreInt32(&connIdled, 1)
	})

	// Read messages (we use a buffer matching the message size to make sure
	// that each iterator of the below loop actually has something to read).
	b := make([]byte, len(msg))
	totalN := 0
	for i := 0; i < dataLoops; i++ {
		n, err := c.Read(b)
		if err != nil {
			t.Fatalf("Problem reading. Read %d bytes, err: %s", n, err)
		}
		totalN += n
	}

	if totalN == 0 {
		t.Fatal("Didn't read any data!")
	}

	// Now read with a really short deadline
	if err := c.SetReadDeadline(time.Now().Add(1 * time.Nanosecond)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}
	_, err = c.Read(msg)
	if netErr, ok := err.(net.Error); ok {
		if !netErr.Timeout() {
			t.Fatalf("Short deadline should have resulted in Timeout, but didn't: %s", err)
		}
	} else {
		t.Fatalf("Short deadline should have resulted in net.Error, but didn't: %s", err)
	}

	time.Sleep(slightlyMoreThanClientTimeout)
	if atomic.LoadInt32(&connIdled) == 0 {
		t.Errorf("Conn failed to idle!")
	}
	_, err = c.Read(make([]byte, 10))
	assert.Equal(t, io.EOF, err, "1st read after idle should return io.EOF")
	_, err = c.Read(make([]byte, 10))
	assert.Equal(t, ErrIdled, err, "2nd read after idle should return ErrIdled")

	time.Sleep(9 * slightlyMoreThanClientTimeout)
	if atomic.LoadInt32(&listenerIdled) == 0 {
		t.Errorf("Listener failed to idle!")
	}
}

func TestClose(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}
	defer func() {
		if err := l.Close(); err != nil {
			t.Fatalf("Unable to close listener: %v", err)
		}
		time.Sleep(1 * time.Second)
		err = fdc.AssertDelta(0)
		if err != nil {
			t.Errorf("File descriptors didn't return to original: %s", err)
		}
	}()

	addr := l.Addr().String()
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Unable to dial %s: %s", addr, err)
	}

	c := Conn(conn, clientTimeout, func() {})
	for i := 0; i < 100; i++ {
		_ = c.Close()
	}
}

// slowConn wraps a net.Conn and ensures that Writes and Reads take
// TargetDuration.
type slowConn struct {
	orig           net.Conn
	targetDuration time.Duration
	readDeadline   time.Time
	writeDeadline  time.Time
}

func (c *slowConn) Read(b []byte) (int, error) {
	targetEnd := time.Now().Add(c.targetDuration)
	if targetEnd.After(c.readDeadline) {
		// Never wait longer than the configured readDeadline
		targetEnd = c.readDeadline
	}
	n, err := c.orig.Read(b)
	sleepTime := targetEnd.Sub(time.Now())
	if sleepTime <= 0 && err == nil {
		err = timeoutError("slowConn timeout")
	}
	if n > 0 {
		time.Sleep(sleepTime)
	}
	return n, err
}

func (c *slowConn) Write(b []byte) (int, error) {
	targetEnd := time.Now().Add(c.targetDuration)
	if targetEnd.After(c.writeDeadline) {
		// Never wait longer than the configured writeDeadline
		targetEnd = c.writeDeadline
	}
	n, err := c.orig.Write(b)
	sleepTime := targetEnd.Sub(time.Now())
	if sleepTime <= 0 && err == nil {
		err = timeoutError("slowConn timeout")
	}
	if n > 0 {
		time.Sleep(sleepTime)
	}
	return n, err
}

func (c *slowConn) Close() error {
	return c.orig.Close()
}

func (c *slowConn) LocalAddr() net.Addr {
	return c.orig.LocalAddr()
}

func (c *slowConn) RemoteAddr() net.Addr {
	return c.orig.RemoteAddr()
}

func (c *slowConn) SetDeadline(t time.Time) error {
	err := c.SetReadDeadline(t)
	if err != nil {
		return err
	}
	return c.SetWriteDeadline(t)
}

func (c *slowConn) SetReadDeadline(t time.Time) error {
	c.readDeadline = t
	return c.orig.SetReadDeadline(t)
}

func (c *slowConn) SetWriteDeadline(t time.Time) error {
	c.writeDeadline = t
	return c.orig.SetWriteDeadline(t)
}

type timeoutError string

func (e timeoutError) Error() string {
	return string(e)
}

func (e timeoutError) Timeout() bool {
	return true
}

func (e timeoutError) Temporary() bool {
	return true
}
