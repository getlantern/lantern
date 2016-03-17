package proxy

import (
	"io"
	"net"
	"testing"

	"github.com/getlantern/testify/assert"
)

var (
	ping = []byte("ping")
	pong = []byte("pong")
)

// Dialer is an interface for types that allowing connecting to some destination
// via an intervening proxy (or proxies).
type Dialer interface {
	// Dial: function that dials a given destination using the proxy.
	Dial(network, addr string) (net.Conn, error)

	// Close: closes the dialer and any underlying resources
	Close() error
}

// Test tests a Dialer.
func Test(t *testing.T, dialer Dialer) {
	// Set up listener for server endpoint
	sl, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	// Server that responds to ping
	go func() {
		conn, err := sl.Accept()
		if err != nil {
			t.Fatalf("Unable to accept connection: %s", err)
			return
		}
		defer func() {
			if err := conn.Close(); err != nil {
				t.Logf("Unable to close connection: %v", err)
			}
		}()
		b := make([]byte, 4)
		_, err = io.ReadFull(conn, b)
		if err != nil {
			t.Fatalf("Unable to read from client: %s", err)
		}
		assert.Equal(t, ping, b, "Didn't receive correct ping message")
		_, err = conn.Write(pong)
		if err != nil {
			t.Fatalf("Unable to write to client: %s", err)
		}
	}()

	conn, err := dialer.Dial("connect", sl.Addr().String())
	if err != nil {
		t.Fatalf("Unable to dial via proxy: %s", err)
	}
	defer func() {
		if err := conn.Close(); err != nil {
			t.Logf("Unable to close connection: %v", err)
		}
	}()

	_, err = conn.Write(ping)
	if err != nil {
		t.Fatalf("Unable to write to server via proxy: %s", err)
	}

	b := make([]byte, 4)
	_, err = io.ReadFull(conn, b)
	if err != nil {
		t.Fatalf("Unable to read from server: %s", err)
	}
	assert.Equal(t, pong, b, "Didn't receive correct pong message")
}
