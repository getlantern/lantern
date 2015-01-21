package balancer

import (
	"fmt"
	"io"
	"math/rand"
	"net"
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

func TestRandomDialer(t *testing.T) {
	dialers := []*dialer{
		&dialer{
			Dialer: &Dialer{
				Label:  "A",
				Weight: 90,
			},
			active: 1,
		}, &dialer{
			Dialer: &Dialer{
				Label:  "B",
				Weight: 9,
			},
			active: 1,
		}, &dialer{
			Dialer: &Dialer{
				Label:  "C",
				Weight: 1,
			},
			active: 1,
		},
	}

	trials := 1000000
	counts := make(map[string]float64)
	for i := 0; i < trials; i++ {
		d, _ := randomDialer(dialers, 0)
		counts[d.Label] = counts[d.Label] + 1
	}
	assertWithinRangeOf(t, counts["A"], .9*float64(trials), .1)
	assertWithinRangeOf(t, counts["B"], .09*float64(trials), .1)
	assertWithinRangeOf(t, counts["C"], .01*float64(trials), .1)
}

func assertWithinRangeOf(t *testing.T, actual float64, expected float64, margin float64) {
	assert.True(t, actual >= expected*(1-margin) && actual <= expected*(1+margin), fmt.Sprintf("%v not within %v of %v", actual, margin, expected))
}

func TestAll(t *testing.T) {
	// Start an echo server
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		log.Fatalf("Unable to listen: %s", err)
	}
	defer l.Close()
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
	addr := l.Addr().String()

	dialedBy := int32(0)

	dialer1Closed := int32(0)
	dialer1 := &Dialer{
		Label:  "Dialer 1",
		Weight: 1,
		QOS:    10,
		Dial: func(network, addr string) (net.Conn, error) {
			atomic.StoreInt32(&dialedBy, 1)
			return net.Dial(network, addr)
		},
		OnClose: func() {
			atomic.StoreInt32(&dialer1Closed, 1)
		},
	}
	dialer2 := &Dialer{
		Weight: 10000000,
		QOS:    1,
		Dial: func(network, addr string) (net.Conn, error) {
			atomic.StoreInt32(&dialedBy, 2)
			return net.Dial(network, addr)
		},
	}
	checkAttempts := int32(0)
	dialer3 := &Dialer{
		Weight: 1,
		QOS:    15,
		Dial: func(network, addr string) (net.Conn, error) {
			atomic.StoreInt32(&dialedBy, 3)
			if atomic.LoadInt32(&checkAttempts) < 6 {
				// Fail for a while
				return nil, fmt.Errorf("Me no dialee")
			} else {
				// Eventually succeed
				return net.Dial(network, addr)
			}
		},
		Check: func() bool {
			time.Sleep(100 * time.Millisecond)
			n := atomic.AddInt32(&checkAttempts, 1)
			return n > 5
		},
	}

	d4attempts := int32(0)
	dialer4 := &Dialer{
		Weight: 1,
		QOS:    15,
		Dial: func(network, addr string) (net.Conn, error) {
			atomic.StoreInt32(&dialedBy, 4)
			defer atomic.AddInt32(&d4attempts, 1)
			if atomic.LoadInt32(&d4attempts) < 1 {
				// Fail once
				return nil, fmt.Errorf("Me no dialee")
			} else {
				// Eventually succeed
				return net.Dial(network, addr)
			}
		},
	}

	// Test failure with no dialers
	b := New()
	_, err = b.Dial("tcp", addr)
	assert.Error(t, err, "Dialing with no dialers should have failed")

	// Test successful single dialer
	b = New(dialer1)
	defer func() {
		b.Close()
		time.Sleep(250 * time.Millisecond)
		assert.Equal(t, int32(1), atomic.LoadInt32(&dialer1Closed), "Dialer 1 should have been closed")
		_, err := b.Dial("tcp", addr)
		if assert.Error(t, err, "Dialing on closed balancer should fail") {
			assert.Contains(t, "No dialers left to try", err.Error(), "Error should have mentioned that there were no dialers left to try")
		}
	}()
	conn, err := b.Dial("tcp", addr)
	assert.NoError(t, err, "Dialing should have succeeded")
	assert.Equal(t, 1, atomic.LoadInt32(&dialedBy), "Wrong dialedBy")
	if err == nil {
		doTestConn(t, conn)
	}

	// Test QOS
	dialedBy = 0
	b = New(dialer1, dialer2)
	defer b.Close()
	conn, err = b.DialQOS("tcp", addr, 5)
	assert.NoError(t, err, "Dialing should have succeeded")
	assert.Equal(t, 1, atomic.LoadInt32(&dialedBy), "Wrong dialedBy")
	if err == nil {
		doTestConn(t, conn)
	}

	// Test random selection
	dialedBy = 0
	conn, err = b.Dial("tcp", addr)
	assert.NoError(t, err, "Dialing should have succeeded")
	assert.Equal(t, 2, atomic.LoadInt32(&dialedBy), "Wrong dialedBy (note this has a 1/%d chance of failing)", (dialer1.Weight + dialer2.Weight))
	if err == nil {
		doTestConn(t, conn)
	}

	// Test success with failing dialer
	dialedBy = 0
	b = New(dialer1, dialer2, dialer3)
	defer b.Close()
	conn, err = b.DialQOS("tcp", addr, 20)
	assert.NoError(t, err, "Dialing should have succeeded")
	assert.Equal(t, 1, atomic.LoadInt32(&dialedBy), "Wrong dialedBy")
	if err == nil {
		doTestConn(t, conn)
	}

	// Test failure
	b = New(dialer3)
	maxCheckTimeout = 100 * time.Millisecond
	// Dial a bunch of times on multiple goroutines to hit different failure branches
	var wg sync.WaitGroup
	wg.Add(2)
	for j := 0; j < 2; j++ {
		bn := b
		go func() {
			for i := 0; i < 50; i++ {
				_, err := bn.Dial("tcp", addr)
				assert.Error(t, err, "Dialing should have failed")
				time.Sleep(10 * time.Millisecond)
			}
			wg.Done()
		}()
	}

	time.Sleep(1 * time.Second)
	assert.Equal(t, 6, atomic.LoadInt32(&checkAttempts), "Wrong number of check attempts on failed dialer")
	wg.Wait()

	// Test success after successful recheck using custom check
	conn, err = b.DialQOS("tcp", addr, 20)
	assert.NoError(t, err, "Dialing should have succeeded")
	assert.Equal(t, 3, atomic.LoadInt32(&dialedBy), "Wrong dialedBy")
	if err == nil {
		doTestConn(t, conn)
	}

	// Test failure
	b = New(dialer4)
	_, err = b.Dial("tcp", addr)
	assert.Error(t, err, "Dialing should have failed")

	time.Sleep(1 * time.Second)
	assert.Equal(t, 2, atomic.LoadInt32(&d4attempts), "Wrong number of dial attempts on failed dialer")

	// Test success after successful retest using default check
	conn, err = b.DialQOS("tcp", addr, 20)
	assert.NoError(t, err, "Dialing should have succeeded")
	assert.Equal(t, 4, atomic.LoadInt32(&dialedBy), "Wrong dialedBy")
	if err == nil {
		doTestConn(t, conn)
	}

}

func doTestConn(t *testing.T, conn net.Conn) {
	defer conn.Close()

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
}

var (
	failed = fmt.Errorf("I failed")
)

type failingConn struct {
	conn         net.Conn
	bytesRead    int
	bytesWritten int
}

func (c *failingConn) Read(b []byte) (n int, err error) {
	n, err = c.conn.Read(b[:c.bytesRead])
	err = failed
	return
}

func (c *failingConn) Write(b []byte) (n int, err error) {
	n, err = c.conn.Write(b[:c.bytesWritten])
	err = failed
	return
}

func (c *failingConn) LocalAddr() net.Addr {
	return c.conn.LocalAddr()
}

func (c *failingConn) RemoteAddr() net.Addr {
	return c.conn.RemoteAddr()
}

func (c *failingConn) SetDeadline(t time.Time) error {
	return c.conn.SetDeadline(t)
}

func (c *failingConn) SetReadDeadline(t time.Time) error {
	return c.conn.SetReadDeadline(t)
}

func (c *failingConn) SetWriteDeadline(t time.Time) error {
	return c.conn.SetWriteDeadline(t)
}

func (c *failingConn) Close() error {
	return c.conn.Close()
}
