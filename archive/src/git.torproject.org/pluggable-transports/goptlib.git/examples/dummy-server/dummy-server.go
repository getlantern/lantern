// Dummy no-op pluggable transport server. Works only as a managed proxy.
//
// Usage (in torrc):
// 	BridgeRelay 1
// 	ORPort 9001
// 	ExtORPort 6669
// 	ServerTransportPlugin dummy exec dummy-server
//
// Because the dummy transport doesn't do anything to the traffic, you can
// connect to it with any ordinary Tor client; you don't have to use
// dummy-client.
package main

import (
	"io"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
)

import "git.torproject.org/pluggable-transports/goptlib.git"

var ptInfo pt.ServerInfo

// When a connection handler starts, +1 is written to this channel; when it
// ends, -1 is written.
var handlerChan = make(chan int)

func copyLoop(a, b net.Conn) {
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		io.Copy(b, a)
		wg.Done()
	}()
	go func() {
		io.Copy(a, b)
		wg.Done()
	}()

	wg.Wait()
}

func handler(conn net.Conn) error {
	defer conn.Close()

	handlerChan <- 1
	defer func() {
		handlerChan <- -1
	}()

	or, err := pt.DialOr(&ptInfo, conn.RemoteAddr().String(), "dummy")
	if err != nil {
		return err
	}
	defer or.Close()

	copyLoop(conn, or)

	return nil
}

func acceptLoop(ln net.Listener) error {
	defer ln.Close()
	for {
		conn, err := ln.Accept()
		if err != nil {
			if e, ok := err.(net.Error); ok && e.Temporary() {
				continue
			}
			return err
		}
		go handler(conn)
	}
}

func main() {
	var err error

	ptInfo, err = pt.ServerSetup(nil)
	if err != nil {
		os.Exit(1)
	}

	listeners := make([]net.Listener, 0)
	for _, bindaddr := range ptInfo.Bindaddrs {
		switch bindaddr.MethodName {
		case "dummy":
			ln, err := net.ListenTCP("tcp", bindaddr.Addr)
			if err != nil {
				pt.SmethodError(bindaddr.MethodName, err.Error())
				break
			}
			go acceptLoop(ln)
			pt.Smethod(bindaddr.MethodName, ln.Addr())
			listeners = append(listeners, ln)
		default:
			pt.SmethodError(bindaddr.MethodName, "no such method")
		}
	}
	pt.SmethodsDone()

	var numHandlers int = 0
	var sig os.Signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// wait for first signal
	sig = nil
	for sig == nil {
		select {
		case n := <-handlerChan:
			numHandlers += n
		case sig = <-sigChan:
		}
	}
	for _, ln := range listeners {
		ln.Close()
	}

	if sig == syscall.SIGTERM {
		return
	}

	// wait for second signal or no more handlers
	sig = nil
	for sig == nil && numHandlers != 0 {
		select {
		case n := <-handlerChan:
			numHandlers += n
		case sig = <-sigChan:
		}
	}
}
