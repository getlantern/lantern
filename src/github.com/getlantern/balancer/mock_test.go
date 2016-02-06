package balancer

import (
	"fmt"
	"io"
	"math/rand"
	"net"
	"time"
)

type EchoConn struct{ b []byte }

func (e *EchoConn) Read(b []byte) (n int, err error) {
	return copy(b, e.b), nil
}

func (e *EchoConn) Write(b []byte) (n int, err error) {
	n = copy(e.b, b)
	e.b = e.b[:n]
	return n, nil
}

func (e *EchoConn) Close() error                             { return nil }
func (e *EchoConn) LocalAddr() net.Addr                      { return nil }
func (e *EchoConn) RemoteAddr() net.Addr                     { return nil }
func (e *EchoConn) SetDeadline(t time.Time) (err error)      { return nil }
func (e *EchoConn) SetReadDeadline(t time.Time) (err error)  { return nil }
func (e *EchoConn) SetWriteDeadline(t time.Time) (err error) { return nil }

func RandomlyFail(failPercent int) *Dialer {
	return RandomlyFailWithDelay(failPercent, 10*time.Millisecond, 0)
}

func RandomlyFailWithDelay(failPercent int, delay time.Duration, delta time.Duration) *Dialer {
	dn := delta.Nanoseconds()
	return &Dialer{
		Label:   fmt.Sprintf("'Fail %d%% %s ± %s dialer'", failPercent, delay.String(), delta.String()),
		Trusted: true,
		Dial: func(string, string) (net.Conn, error) {
			var cdn int64
			if dn != 0 {
				cdn = rand.Int63n(dn*2) - dn
			}
			time.Sleep(delay + time.Duration(cdn)*time.Nanosecond)
			if rand.Intn(100) < failPercent {
				return nil, io.EOF
			}
			return &EchoConn{}, nil
		},
	}
}

func EchoServer() net.Listener {
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
			go func(c net.Conn) {
				io.Copy(c, c)
				c.Close()
			}(conn)
		}
	}()
	return l
}
