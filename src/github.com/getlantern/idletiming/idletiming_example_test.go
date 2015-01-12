package idletiming

import (
	"log"
	"net"
	"time"
)

func ExampleConn() {
	c, err := net.Dial("tcp", "127.0.0.1:8080")
	if err != nil {
		log.Fatalf("Unable to dial %s", err)
	}

	ic := Conn(c, 5*time.Second, func() {
		log.Printf("Connection was idled")
	})

	ic.Write([]byte("My data"))
}

func ExampleListener() {
	l, err := net.Listen("tcp", "127.0.0.1:8080")
	if err != nil {
		log.Fatalf("Unable to listen %s", err)
	}

	il := Listener(l, 5*time.Second, func(conn net.Conn) {
		log.Printf("Connection was idled")
	})

	il.Accept()
}
