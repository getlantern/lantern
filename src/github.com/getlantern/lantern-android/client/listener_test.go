package client

import (
	"net"
	"testing"
)

const (
	listenAddr = "127.0.0.1:9298"
)

var ln *listener

func TestListenerSpawn(t *testing.T) {
	var err error

	// Are we capable of creating a listener?
	if ln, err = newListener(listenAddr); err != nil {
		t.Fatal(err)
	}

	// Move Accept inside a goroutine.
	go func() {
		for {
			if _, err = ln.Accept(); err != nil {
				return
			}
		}
	}()

}

func TestListenerConnectToNewListener(t *testing.T) {
	var err error

	// Attempt to connect to the listener we've created.
	if _, err = net.Dial("tcp", listenAddr); err != nil {
		t.Fatal(err)
	}
}

func TestListenerStop(t *testing.T) {
	var err error

	// Attempt to stop the listener we've created.
	if err = ln.Stop(); err != nil {
		t.Fatal(err)
	}
}

func TestListenerConnectToClosedListener(t *testing.T) {
	var err error

	// We should not be able to connect.
	if _, err = net.Dial("tcp", listenAddr); err == nil {
		t.Fatal("Should have failed.")
	}
}

func TestListenerRespawnOnSameAddress(t *testing.T) {
	var err error

	// Attempt to create a listener at the same address should succeed, since
	// we've closed the old listener.
	if _, err = newListener(listenAddr); err != nil {
		t.Fatal(err)
	}
}
