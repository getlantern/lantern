// Copyright 2015 Igor Dolzhikov. All rights reserved.
// Use of this source code is governed by
// license that can be found in the LICENSE file.

/*
Package daemon 0.2.8 for use with Go (golang) services.

Package daemon provides primitives for daemonization of golang services.
This package is not provide implementation of user daemon,
accordingly must have root rights to install/remove service.
In the current implementation is only supported Linux and Mac Os X daemon.

Example:

	// Example of a daemon with echo service
	package main

	import (
		"fmt"
		"log"
		"net"
		"os"
		"os/signal"
		"syscall"

		"github.com/takama/daemon"
	)

	const (

		// name of the service, match with executable file name
		name        = "myservice"
		description = "My Echo Service"

		// port which daemon should be listen
		port = ":9977"
	)

	var stdlog, errlog *log.Logger

	// Service has embedded daemon
	type Service struct {
		daemon.Daemon
	}

	// Manage by daemon commands or run the daemon
	func (service *Service) Manage() (string, error) {

		usage := "Usage: myservice install | remove | start | stop | status"

		// if received any kind of command, do it
		if len(os.Args) > 1 {
			command := os.Args[1]
			switch command {
			case "install":
				return service.Install()
			case "remove":
				return service.Remove()
			case "start":
				return service.Start()
			case "stop":
				return service.Stop()
			case "status":
				return service.Status()
			default:
				return usage, nil
			}
		}

		// Do something, call your goroutines, etc

		// Set up channel on which to send signal notifications.
		// We must use a buffered channel or risk missing the signal
		// if we're not ready to receive when the signal is sent.
		interrupt := make(chan os.Signal, 1)
		signal.Notify(interrupt, os.Interrupt, os.Kill, syscall.SIGTERM)

		// Set up listener for defined host and port
		listener, err := net.Listen("tcp", port)
		if err != nil {
			return "Possibly was a problem with the port binding", err
		}

		// set up channel on which to send accepted connections
		listen := make(chan net.Conn, 100)
		go acceptConnection(listener, listen)

		// loop work cycle with accept connections or interrupt
		// by system signal
		for {
			select {
			case conn := <-listen:
				go handleClient(conn)
			case killSignal := <-interrupt:
				stdlog.Println("Got signal:", killSignal)
				stdlog.Println("Stoping listening on ", listener.Addr())
				listener.Close()
				if killSignal == os.Interrupt {
					return "Daemon was interruped by system signal", nil
				}
				return "Daemon was killed", nil
			}
		}

		// never happen, but need to complete code
		return usage, nil
	}

	// Accept a client connection and collect it in a channel
	func acceptConnection(listener net.Listener, listen chan<- net.Conn) {
		for {
			conn, err := listener.Accept()
			if err != nil {
				continue
			}
			listen <- conn
		}
	}

	func handleClient(client net.Conn) {
		for {
			buf := make([]byte, 4096)
			numbytes, err := client.Read(buf)
			if numbytes == 0 || err != nil {
				return
			}
			client.Write(buf)
		}
	}

	func init() {
		stdlog = log.New(os.Stdout, "", log.Ldate|log.Ltime)
		errlog = log.New(os.Stderr, "", log.Ldate|log.Ltime)
	}

	func main() {
		srv, err := daemon.New(name, description)
		if err != nil {
			errlog.Println("Error: ", err)
			os.Exit(1)
		}
		service := &Service{srv}
		status, err := service.Manage()
		if err != nil {
			errlog.Println(status, "\nError: ", err)
			os.Exit(1)
		}
		fmt.Println(status)
	}

Go daemon
*/
package daemon

// Daemon interface has standard set of a methods/commands
type Daemon interface {

	// Install the service into the system
	Install() (string, error)

	// Remove the service and all corresponded files from the system
	Remove() (string, error)

	// Start the service
	Start() (string, error)

	// Stop the service
	Stop() (string, error)

	// Status - check the service status
	Status() (string, error)
}

// New - Create a new daemon
//
// name: name of the service, match with executable file name;
// description: any explanation, what is the service, its purpose
func New(name, description string) (Daemon, error) {
	return newDaemon(name, description)
}
