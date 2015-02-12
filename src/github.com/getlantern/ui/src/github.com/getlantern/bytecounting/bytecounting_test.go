package bytecounting

import (
	"io/ioutil"
	"net"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

var (
	req  = []byte("Hello There")
	resp = []byte("Hello Yourself")

	dataLoops = 10

	clientTimeout                 = 25 * time.Millisecond
	serverTimeout                 = 10 * clientTimeout
	slightlyLessThanClientTimeout = time.Duration(int64(float64(clientTimeout.Nanoseconds()) * 0.9))
	slightlyMoreThanClientTimeout = time.Duration(int64(float64(clientTimeout.Nanoseconds()) * 1.1))
)

func TestCounting(t *testing.T) {
	lr := int64(0)
	lw := int64(0)
	cr := int64(0)
	cw := int64(0)

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	il := &Listener{
		Orig: l,
		OnRead: func(bytes int64) {
			atomic.AddInt64(&lr, bytes)
		},
		OnWrite: func(bytes int64) {
			atomic.AddInt64(&lw, bytes)
		},
	}
	defer il.Close()

	go func() {
		conn, err := il.Accept()
		if err != nil {
			t.Fatalf("Unable to accept: %s", err)
		}
		b := make([]byte, len(req))
		conn.Read(b)
		conn.Write(resp)
		conn.Close()
	}()

	addr := il.Addr().String()
	c, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Unable to dial %s: %s", addr, err)
	}

	conn := &Conn{
		Orig: c,
		OnRead: func(bytes int64) {
			atomic.AddInt64(&cr, bytes)
		},
		OnWrite: func(bytes int64) {
			atomic.AddInt64(&cw, bytes)
		},
	}

	// Test info methods
	assert.Equal(t, c.LocalAddr(), conn.LocalAddr(), "LocalAddr should be same as on underlying")
	assert.Equal(t, c.RemoteAddr(), conn.RemoteAddr(), "RemoteAddr should be same as on underlying")

	// Test short ReadDeadline
	conn.SetReadDeadline(time.Now().Add(-1 * time.Second))
	b := make([]byte, len(resp))
	_, err = conn.Read(b)
	assertTimeoutError(t, err)
	conn.SetReadDeadline(time.Now().Add(1 * time.Hour))

	// Test short WriteDeadline
	conn.SetWriteDeadline(time.Now().Add(-1 * time.Second))
	_, err = conn.Write([]byte{})
	assertTimeoutError(t, err)
	conn.SetWriteDeadline(time.Now().Add(1 * time.Hour))

	// Test short Deadline
	conn.SetDeadline(time.Now().Add(-1 * time.Second))
	_, err = conn.Read(b)
	assertTimeoutError(t, err)
	_, err = conn.Write([]byte{})
	assertTimeoutError(t, err)
	conn.SetDeadline(time.Now().Add(1 * time.Hour))

	_, err = conn.Write(req)
	if err != nil {
		t.Fatalf("Unable to write: %v", err)
	}
	ioutil.ReadAll(conn)

	assert.Equal(t, int64(len(resp)), cr, "Wrong number of bytes read by conn")
	assert.Equal(t, int64(len(req)), cw, "Wrong number of bytes written by conn")
	assert.Equal(t, cr, lw, "Listener written should equal conn read")
	assert.Equal(t, cw, lr, "Listener read should equal conn written")
}

func assertTimeoutError(t *testing.T, err error) {
	switch e := err.(type) {
	case net.Error:
		assert.True(t, e.Timeout(), "Error should be timeout")
	default:
		assert.Fail(t, "Error should be net.Error")
	}
}
