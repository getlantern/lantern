package balancer

import (
	"fmt"
	"net"
	"testing"
)

func newDialerTo(l net.Listener) *Dialer {
	return &Dialer{
		Label:   l.Addr().String(),
		Trusted: true,
		Dial: func(string, string) (net.Conn, error) {
			return net.Dial(l.Addr().Network(), l.Addr().String())
		},
	}
}
func BenchmarkSticky(b *testing.B) {
	l1 := RandomlyFail(5)
	d1 := newDialerTo(l1)
	l2 := RandomlyFail(50)
	d2 := newDialerTo(l2)
	bal := New(Sticky, d1, d2)
	buf := make([]byte, 100)
	for i := 0; i < b.N; i++ { //use b.N for looping
		c, err := bal.Dial("xxx", "yyy")
		if err != nil {
			log.Fatal(err)
		}
		nw, err := c.Write([]byte(fmt.Sprintf("iteration %d", i)))
		if err != nil {
			log.Fatal(err)
		}
		nr, err := c.Read(buf)
		if err != nil {
			i--
			continue
		}
		if nr != nw {
			log.Fatal("not equal!")
		}
	}
}
