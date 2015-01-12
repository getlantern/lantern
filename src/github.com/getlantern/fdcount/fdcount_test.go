package fdcount

import (
	"net"
	"testing"

	"github.com/getlantern/testify/assert"
)

func TestTCP(t *testing.T) {
	l0, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l0.Close()

	start, fdc, err := Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}
	assert.Equal(t, 1, start, "Starting count should have been 1")

	err = fdc.AssertDelta(0)
	if err != nil {
		t.Fatal(err)
	}
	assert.NoError(t, err, "Initial TCP count should be 0")

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()

	err = fdc.AssertDelta(0)
	if assert.Error(t, err, "Asserting wrong count should fail") {
		assert.Contains(t, err.Error(), "Expected 0, have 1")
		assert.True(t, len(err.Error()) > 100)
	}
	err = fdc.AssertDelta(1)
	assert.NoError(t, err, "Ending TCP count should be 1")
}
