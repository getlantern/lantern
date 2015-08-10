package waitforserver

import (
	"net"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

func TestSuccess(t *testing.T) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}
	defer func() {
		if err := l.Close(); err != nil {
			t.Fatalf("Unable to close listener: %v", err)
		}
	}()
	err = WaitForServer("tcp", l.Addr().String(), 100*time.Millisecond)
	assert.NoError(t, err, "Server should have been found")
}

func TestFailure(t *testing.T) {
	err := WaitForServer("tcp", "localhost:18900", 100*time.Millisecond)
	assert.Error(t, err, "Server should not have been found")
}
