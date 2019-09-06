package idletiming

import (
	"net"
	"time"
)

func ExampleConn() {
	c, err := net.Dial("tcp", "127.0.0.1:8080")
	if err != nil {
		log.Fatalf("Unable to dial %s", err)
	}

	ic := Conn(c, 5*time.Second, func() {
		log.Debugf("Connection was idled")
	})

	if _, err := ic.Write([]byte("My data")); err != nil {
		log.Fatalf("Unable to write to connection: %v", err)
	}
}

func ExampleListener() {
	l, err := net.Listen("tcp", "127.0.0.1:8080")
	if err != nil {
		log.Fatalf("Unable to listen %s", err)
	}

	il := Listener(l, 5*time.Second, func(conn net.Conn) {
		log.Debugf("Connection was idled")
	})

	if _, err := il.Accept(); err != nil {
		log.Fatalf("Unable to accept connections: %v", err)
	}
}
