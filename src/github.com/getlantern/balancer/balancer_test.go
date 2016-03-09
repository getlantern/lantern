package balancer

import (
	"fmt"
	"io"
	"math/rand"
	"net"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

var (
	msg = []byte("Hello world")
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func TestNoDialers(t *testing.T) {
	addr, l := echoServer()
	defer func() { _ = l.Close() }()
	b := New(Sticky)
	_, err := b.Dial("tcp", addr)
	assert.Error(t, err, "Dialing with no dialers should have failed")
}

func TestSingleDialer(t *testing.T) {
	addr, l := echoServer()
	defer func() { _ = l.Close() }()

	dialer := newDialer(1)
	dialerClosed := int32(0)
	dialer.OnClose = func() {
		atomic.StoreInt32(&dialerClosed, 1)
	}
	// Test successful single dialer
	b := New(Sticky, dialer)
	conn, err := b.Dial("tcp", addr)
	if assert.NoError(t, err, "Dialing should have succeeded") {
		doTestConn(t, conn)
	}

	// Test close balancer
	b.Close()
	time.Sleep(250 * time.Millisecond)
	assert.Equal(t, int32(1), atomic.LoadInt32(&dialerClosed), "Dialer should have been closed")
	_, err = b.Dial("tcp", addr)
	if assert.Error(t, err, "Dialing on closed balancer should fail") {
		assert.Contains(t, "No dialers left to try on pass 0", err.Error(), "Error should have mentioned that there were no dialers left to try")
	}
}

func TestRandomDialer(t *testing.T) {
	addr, l := echoServer()
	defer func() { _ = l.Close() }()
	d1Attempts := 0
	dialer1 := newFailingDialer(1, func() bool { d1Attempts++; return false })
	d2Attempts := 0
	dialer2 := newFailingDialer(2, func() bool { d2Attempts++; return false })
	d3Attempts := 0
	dialer3 := newFailingDialer(3, func() bool { d3Attempts++; return false })

	// Test success with failing dialer
	b := New(Random, dialer1, dialer2, dialer3)
	defer b.Close()
	for i := 0; i < 3000; i++ {
		_, err := b.Dial("tcp", addr)
		assert.NoError(t, err, "Dialing should have succeeded")
	}
	assertWithinRangeOf(t, d1Attempts, 1000, 100)
	assertWithinRangeOf(t, d2Attempts, 1000, 100)
	assertWithinRangeOf(t, d3Attempts, 1000, 100)
}

func TestLoadBalancing(t *testing.T) {
	addr, l := echoServer()
	defer func() { _ = l.Close() }()
	d1Attempts := 0
	dialer1 := newLatencyDialer(1, 1*time.Millisecond, 100*time.Nanosecond, &d1Attempts)
	d2Attempts := 0
	dialer2 := newLatencyDialer(2, 1*time.Millisecond, 100*time.Nanosecond, &d2Attempts)
	d3Attempts := 0
	dialer3 := newLatencyDialer(3, 2*time.Millisecond, 100*time.Nanosecond, &d3Attempts)
	d4Attempts := 0
	dialer4 := newFailingDialer(1, func() bool {
		// 5% fail rate
		d4Attempts++
		if rand.Intn(100) < 5 {
			return false
		}
		return true
	})

	// Test success with failing dialer
	b := New(QualityFirst, dialer1, dialer2, dialer3, dialer4)
	defer b.Close()
	for i := 0; i < 100; i++ {
		_, err := b.Dial("tcp", addr)
		assert.NoError(t, err, "Dialing should have succeeded")
	}
	// QualityFirst strategy provides some sort of load balancing, but not fair enough
	assertWithinRangeOf(t, d1Attempts, 50, 40)
	assertWithinRangeOf(t, d2Attempts, 50, 40)
	assertWithinRangeOf(t, d3Attempts, 10, 10)
	assertWithinRangeOf(t, d4Attempts, 2, 2)
}

func assertWithinRangeOf(t *testing.T, actual int, expected int, margin int) {
	assert.True(t, actual >= expected-margin && actual <= expected+margin, fmt.Sprintf("%v not within %v of %v", actual, margin, expected))
}

func TestSuccessWithFailingDialer(t *testing.T) {
	addr, l := echoServer()
	defer func() { _ = l.Close() }()
	dialer1 := newFailingDialer(1, func() bool { return true })
	dialer2 := newDialer(2)
	dialer3 := newDialer(3)

	// Test success with failing dialer
	b := New(Sticky, dialer1, dialer2, dialer3)
	defer b.Close()
	conn, err := b.Dial("tcp", addr)
	if assert.NoError(t, err, "Dialing should have succeeded") {
		doTestConn(t, conn)
	}
}

func TestRecheck(t *testing.T) {
	addr, l := echoServer()
	defer func() { _ = l.Close() }()
	attempts := int32(0)
	dialer := newFailingDialer(1, func() bool { attempts++; return attempts <= 1 })
	// Test failure
	b := New(Sticky, dialer, dialer)
	_, err := b.Dial("tcp", addr)
	assert.NoError(t, err, "Dialing should have succeeded as we have 2nd try")
	assert.Equal(t, 2, atomic.LoadInt32(&attempts), "Wrong number of dial attempts on failed dialer")

	// Test success after successful retest using default check
	conn, err := b.Dial("tcp", addr)
	if assert.NoError(t, err, "Dialing should have succeeded") {
		doTestConn(t, conn)
	}
}

func TestTrusted(t *testing.T) {
	dialCount := 0
	dialer := &Dialer{
		Dial: func(network, addr string) (net.Conn, error) {
			dialCount++
			return nil, nil
		},
	}

	_, err := New(Sticky, dialer).Dial("tcp", "does-not-exist.com:80")
	assert.Error(t, err, "Dialing with no trusted dialers should have failed")
	assert.Equal(t, dialCount, 0, "should not dial untrusted dialer")

	_, err = New(Sticky, dialer).Dial("tcp", "does-not-exist.com:8080")
	assert.Error(t, err, "Dialing with no trusted dialers should have failed")
	assert.Equal(t, dialCount, 0, "should not dial untrusted dialer")

	dialer.Trusted = true
	_, err = New(Sticky, dialer).Dial("tcp", "does-not-exist.com:80")
	assert.NoError(t, err, "Dialing with trusted dialer should have succeeded")
	assert.Equal(t, dialCount, 1, "should dial untrusted dialer")
	_, err = New(Sticky, dialer).Dial("tcp", "does-not-exist.com:8080")
	assert.NoError(t, err, "Dialing with trusted dialer should have succeeded")
	assert.Equal(t, dialCount, 2, "should dial untrusted dialer")
}

func echoServer() (addr string, l net.Listener) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		log.Fatalf("Unable to listen: %s", err)
	}
	go func() {
		for {
			c, err := l.Accept()
			if err == nil {
				go func() {
					_, err = io.Copy(c, c)
					if err != nil {
						log.Fatalf("Unable to echo: %s", err)
					}
				}()
			}
		}
	}()
	addr = l.Addr().String()
	return
}

func newDialer(id int) *Dialer {
	dialer := &Dialer{
		Label: fmt.Sprintf("Dialer %d", id),
		Dial: func(network, addr string) (net.Conn, error) {
			return net.Dial(network, addr)
		},
	}
	return dialer
}

func newLatencyDialer(id int, latency time.Duration, delta time.Duration, attempts *int) *Dialer {
	dialer := &Dialer{
		Label: fmt.Sprintf("Dialer %d", id),
		Dial: func(network, addr string) (net.Conn, error) {
			t := int64(latency) + rand.Int63n(int64(delta)*2) - int64(delta)
			time.Sleep(time.Duration(t))
			*attempts++
			return net.Dial(network, addr)
		},
	}
	return dialer
}

// newFailingDialer creates a dialer that will fail if shouldFail returns true.
func newFailingDialer(id int32, shouldFail func() bool) *Dialer {
	d := &Dialer{
		Label: "Dialer " + strconv.Itoa(int(id)),
		Dial: func(network, addr string) (net.Conn, error) {
			if shouldFail() {
				return nil, fmt.Errorf("Failing intentionally")
			} else {
				return net.Dial(network, addr)
			}
		},
	}
	return d
}

func doTestConn(t *testing.T, conn net.Conn) {
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		n, err := conn.Write(msg)
		assert.NoError(t, err, "Writing should have succeeded")
		assert.Equal(t, len(msg), n, "Should have written full message")
		wg.Done()
	}()
	go func() {
		b := make([]byte, len(msg))
		n, err := io.ReadFull(conn, b)
		assert.NoError(t, err, "Read should have succeeded")
		assert.Equal(t, len(msg), n, "Should have read full message")
		assert.Equal(t, msg, b[:n], "Read should have matched written")
		wg.Done()
	}()

	wg.Wait()
	err := conn.Close()
	assert.NoError(t, err, "Should close conn")
}
