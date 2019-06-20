package connpool

import (
	"fmt"
	"io/ioutil"
	"math/rand"
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/waitforserver"
	"github.com/stretchr/testify/assert"
)

var (
	msg          = []byte("HELLO")
	fillTime     = 100 * time.Millisecond
	claimTimeout = 1 * time.Second
)

func TestIt(t *testing.T) {
	poolSize := 20

	addr, err := startTestServer()
	if err != nil {
		t.Fatalf("Unable to start test server: %s", err)
	}

	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	randomlyClose := int32(0)

	p := New(Config{
		Size:         poolSize,
		ClaimTimeout: claimTimeout,
		Dial: func() (net.Conn, error) {
			conn, err := net.DialTimeout("tcp", addr, 15*time.Millisecond)
			if atomic.LoadInt32(&randomlyClose) == 1 {
				// Close about half of the connections immediately to test
				/// closed checking
				if err == nil && rand.Float32() > 0.5 {
					if err := conn.Close(); err != nil {
						t.Fatalf("Unable to close connection: %v", err)
					}
				}
			}
			return conn, err
		},
	})

	time.Sleep(fillTime)

	assert.NoError(t, fdc.AssertDelta(0), "Pool should initially contain no conns")

	// Use more than the pooled connections
	connectAndRead(t, p, poolSize*2)

	time.Sleep(fillTime)
	assert.NoError(t, fdc.AssertDelta(poolSize), "Pool should fill itself back up to the right number of conns")

	// Wait for connections to time out
	time.Sleep(claimTimeout * 2)

	assert.NoError(t, fdc.AssertDelta(0), "After connections time out, but before dialing again, pool should be empty")

	// Test our connections again
	connectAndRead(t, p, poolSize*2)

	time.Sleep(fillTime)
	assert.NoError(t, fdc.AssertDelta(poolSize), "After pooled conns time out, pool should fill itself back up to the right number of conns")

	atomic.StoreInt32(&randomlyClose, 1)

	// Make sure we can still get connections and use them
	connectAndRead(t, p, poolSize)

	// Wait for pool to fill again
	time.Sleep(fillTime)

	p.Close()
	// Run another Close() concurrently just to make sure it doesn't muck things up
	go p.Close()

	assert.NoError(t, fdc.AssertDelta(0), "After stopping pool, there should be no more open conns")
}

func TestDialFailure(t *testing.T) {
	fail := int32(1)
	dialAttempts := int32(0)

	addr, err := startTestServer()
	if err != nil {
		t.Fatalf("Unable to start test server: %s", err)
	}

	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	poolSize := 10

	p := New(Config{
		Size: poolSize,
		Dial: func() (net.Conn, error) {
			atomic.AddInt32(&dialAttempts, 1)
			if atomic.LoadInt32(&fail) == int32(1) {
				return nil, fmt.Errorf("I'm failing intentionally!")
			}
			return net.DialTimeout("tcp", addr, 15*time.Millisecond)
		},
	})

	// Try to get connection, make sure it fails
	conn, err := p.Get()
	if !assert.Error(t, err, "Dialing should have failed") {
		if err := conn.Close(); err != nil {
			t.Fatalf("Unable to close connection: %v", err)
		}
	}

	// Wait for fill to run for a while with a failing connection
	time.Sleep(1 * time.Second)
	assert.EqualValues(t, 1, atomic.LoadInt32(&dialAttempts), fmt.Sprintf("There should have been only 1 dial attempt"))
	assert.NoError(t, fdc.AssertDelta(0), "There should be no additional file descriptors open")

	// Now make connection succeed and verify that it works
	atomic.StoreInt32(&fail, 0)
	time.Sleep(100 * time.Millisecond)
	connectAndRead(t, p, 1)

	time.Sleep(fillTime)
	log.Debug("Testing")
	assert.NoError(t, fdc.AssertDelta(10), "Pool should have filled")

	// Now make the connection fail again so that when we stop, we're stopping
	// while failing (tests a different code path for stopping)
	atomic.StoreInt32(&fail, 1)
	time.Sleep(100 * time.Millisecond)

	p.Close()

	assert.NoError(t, fdc.AssertDelta(0), "All connections should be closed")
}

func TestPropertyChange(t *testing.T) {
	claimTimeout := 5 * time.Second

	cfg := &Config{
		ClaimTimeout: claimTimeout,
	}
	p := New(*cfg)
	defer p.Close()

	cfg.ClaimTimeout = 7 * time.Second
	assert.Equal(t, claimTimeout, p.(*pool).Config.ClaimTimeout, "Property changed on config shouldn't be reflected in pool")
}

func connectAndRead(t *testing.T, p Pool, loops int) {
	var wg sync.WaitGroup

	for i := 0; i < loops; i++ {
		wg.Add(1)

		func(wg *sync.WaitGroup) {
			c, err := p.Get()
			if err != nil {
				t.Fatalf("Error getting connection: %s", err)
			}
			read, err := ioutil.ReadAll(c)
			if err != nil {
				t.Fatalf("Error reading from connection: %s", err)
			}
			assert.Equal(t, msg, read, "Should have received %s from server", string(msg))
			if err := c.Close(); err != nil {
				t.Fatalf("Unable to close connection: %v", err)
			}

			wg.Done()
		}(&wg)
	}

	wg.Wait()
}

func startTestServer() (string, error) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", err
	}
	err = waitforserver.WaitForServer("tcp", l.Addr().String(), 1*time.Second)
	if err != nil {
		return "", err
	}
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				log.Fatalf("Error listening: %s", err)
			}
			if _, err = c.Write(msg); err != nil {
				log.Fatalf("Unable to write message: %s", err)
			}
			if err := c.Close(); err != nil {
				log.Fatalf("Unable to close connection: %v", err)
			}
		}
	}()
	return l.Addr().String(), nil
}
