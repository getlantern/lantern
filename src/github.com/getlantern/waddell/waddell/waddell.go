package main

import (
	"flag"

	"github.com/getlantern/golog"
	"github.com/getlantern/waddell"
)

var (
	log = golog.LoggerFor("waddell")

	addr     = flag.String("addr", ":62443", "host:port on which to listen for client connections")
	pkfile   = flag.String("pkfile", "", "Location of private key file (optional)")
	certfile = flag.String("certfile", "", "Location of certificate (optional)")
)

func main() {
	flag.Parse()
	server := &waddell.Server{}
	if *pkfile != "" {
		log.Debugf("Starting waddell with TLS over TCP at %s", *addr)
	} else {
		log.Debugf("Starting waddell with plain text TCP at %s", *addr)
	}
	listener, err := waddell.Listen(*addr, *pkfile, *certfile)
	if err != nil {
		log.Fatalf("Unable to listen at %s: %s", *addr, err)
	}
	err = server.Serve(listener)
	if err != nil {
		log.Fatalf("Unable to start waddell at %s: %s", *addr, err)
	}
}
