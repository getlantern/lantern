package balancer

import (
	"io"
	"math/rand"
	"net"
)

type Handler func(c net.Conn)

func RandomlyFail(failPercent int) net.Listener {
	return newServer(func(c net.Conn) {
		if rand.Intn(100) < failPercent {
			c.Close()
			return
		}
		io.Copy(c, c)
		c.Close()
	})
}

func newServer(h Handler) net.Listener {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		log.Fatal(err)
	}
	go func() {
		for {
			conn, err := l.Accept()
			if err != nil {
				log.Fatal(err)
			}
			go h(conn)
		}
	}()
	return l
}
