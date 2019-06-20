package bytecounting

import (
	"io/ioutil"
	"net"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
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
	defer func() {
		if err := il.Close(); err != nil {
			t.Fatalf("Unable to close listener: %v", err)
		}
	}()

	go func() {
		conn, err := il.Accept()
		if err != nil {
			t.Fatalf("Unable to accept: %s", err)
		}
		b := make([]byte, len(req))
		if _, err := conn.Read(b); err != nil {
			t.Fatalf("Unable to read from connection: %v", err)
		}
		if _, err := conn.Write(resp); err != nil {
			t.Fatalf("Unable to write to connection: %v", err)
		}
		if err := conn.Close(); err != nil {
			t.Fatalf("Unable to close connection: %v", err)
		}
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
	if err := conn.SetReadDeadline(time.Now().Add(-1 * time.Second)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}
	b := make([]byte, len(resp))
	_, err = conn.Read(b)
	assertTimeoutError(t, err)
	if err := conn.SetReadDeadline(time.Now().Add(1 * time.Hour)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}

	// Test short WriteDeadline
	if err := conn.SetWriteDeadline(time.Now().Add(-1 * time.Second)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}
	_, err = conn.Write([]byte{})
	assertTimeoutError(t, err)
	if err := conn.SetWriteDeadline(time.Now().Add(1 * time.Hour)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}

	// Test short Deadline
	if err := conn.SetDeadline(time.Now().Add(-1 * time.Second)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}
	_, err = conn.Read(b)
	assertTimeoutError(t, err)
	_, err = conn.Write([]byte{})
	assertTimeoutError(t, err)
	if err := conn.SetDeadline(time.Now().Add(1 * time.Hour)); err != nil {
		t.Fatalf("Unable to set read deadline: %v", err)
	}

	if _, err = conn.Write(req); err != nil {
		t.Fatalf("Unable to write: %v", err)
	}
	if _, err := ioutil.ReadAll(conn); err != nil {
		t.Fatalf("Unable to read: %v", err)
	}

	assert.Equal(t, int64(len(resp)), atomic.LoadInt64(&cr), "Wrong number of bytes read by conn")
	assert.Equal(t, int64(len(req)), atomic.LoadInt64(&cw), "Wrong number of bytes written by conn")
	assert.Equal(t, atomic.LoadInt64(&cr), atomic.LoadInt64(&lw), "Listener written should equal conn read")
	assert.Equal(t, atomic.LoadInt64(&cw), atomic.LoadInt64(&lr), "Listener read should equal conn written")
}

func assertTimeoutError(t *testing.T, err error) {
	switch e := err.(type) {
	case net.Error:
		assert.True(t, e.Timeout(), "Error should be timeout")
	default:
		assert.Fail(t, "Error should be net.Error")
	}
}
