package client

import (
	"net"
	"testing"
)

const (
	listenAddr = "127.0.0.1:9298"
)

var ln *Listener

func TestListenerSpawn(t *testing.T) {
	var err error

	if ln, err = NewListener(listenAddr); err != nil {
		t.Fatal(err)
	}

	go func() {
		for {
			if _, err = ln.Accept(); err != nil {
				return
			}
		}
	}()

}

func TestListenerConnect(t *testing.T) {
	var err error

	if _, err = net.Dial("tcp", listenAddr); err != nil {
		t.Fatal(err)
	}
}

func TestListenerStop(t *testing.T) {
	var err error

	if err = ln.Stop(); err != nil {
		t.Fatal(err)
	}
}

func TestListenerRejectedConn(t *testing.T) {
	var err error

	if _, err = net.Dial("tcp", listenAddr); err == nil {
		t.Fatal("Should have failed.")
	}
}

func TestListenerRespawn(t *testing.T) {
	var err error

	if _, err = NewListener(listenAddr); err != nil {
		t.Fatal(err)
	}
}
