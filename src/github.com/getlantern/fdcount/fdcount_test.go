package fdcount

import (
	"net"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

func TestTCP(t *testing.T) {
	// Lower maxAssertAttempts to keep this test from running too long
	maxAssertAttempts = 2

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
	_, middle, err := Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	err = fdc.AssertDelta(0)
	if assert.Error(t, err, "Asserting wrong count should fail") {
		assert.Contains(t, err.Error(), "Expected 0, have 1")
		assert.True(t, len(err.Error()) > 100)
	}
	err = fdc.AssertDelta(1)
	assert.NoError(t, err, "Ending TCP count should be 1")

	err = fdc.AssertDelta(0)
	if assert.Error(t, err, "Asserting wrong count should fail") {
		assert.Contains(t, err.Error(), "Expected 0, have 1")
		assert.Contains(t, err.Error(), "New")
		assert.True(t, len(err.Error()) > 100)
	}

	l.Close()
	err = middle.AssertDelta(0)
	if assert.Error(t, err, "Asserting wrong count should fail") {
		assert.Contains(t, err.Error(), "Expected 0, have -1")
		assert.Contains(t, err.Error(), "Removed")
		assert.True(t, len(err.Error()) > 100)
	}
}

func TestWaitUntilNoneMatchOK(t *testing.T) {
	conn, err := net.Dial("tcp", "www.google.com:80")
	if err != nil {
		t.Fatalf("Unable to dial google: %v", err)
	}
	defer conn.Close()

	wait := 250 * time.Millisecond
	start := time.Now()
	go func() {
		time.Sleep(wait)
		conn.Close()
	}()

	err = WaitUntilNoneMatch("TCP", wait*2)
	elapsed := time.Now().Sub(start)
	assert.NoError(t, err, "Waiting should have succeeded")
	assert.True(t, elapsed >= wait, "Should have waited a while")
}

func TestWaitUntilNoneMatchTimeout(t *testing.T) {
	conn, err := net.Dial("tcp", "www.google.com:80")
	if err != nil {
		t.Fatalf("Unable to dial google: %v", err)
	}
	defer conn.Close()

	wait := 250 * time.Millisecond
	start := time.Now()
	go func() {
		time.Sleep(wait)
		conn.Close()
	}()

	err = WaitUntilNoneMatch("TCP", wait/2)
	elapsed := time.Now().Sub(start)
	assert.Error(t, err, "Waiting should have failed")
	assert.True(t, elapsed < wait, "Should have waited less than time to close conn")
}
