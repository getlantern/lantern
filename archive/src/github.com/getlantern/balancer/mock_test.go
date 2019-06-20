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
	return RandomlyFailWithVariedDelay(failPercent, 10*time.Nanosecond, 0)
}

func RandomlyFailWithVariedDelay(failPercent int, delay time.Duration, delta time.Duration) *Dialer {
	dn := delta.Nanoseconds()
	label := fmt.Sprintf("'%d%% %s±%s'", failPercent, delay.String(), delta.String())
	return &Dialer{
		Label:   label,
		Trusted: true,
		DialFN: func(string, string) (net.Conn, error) {
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

func echoServer() (addr string, l net.Listener) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		log.Fatalf("Unable to listen: %s", err)
	}
	go func() {
		for {
			c, err := l.Accept()
			if err == nil {
				go func() {
					_, err = io.Copy(c, c)
					if err != nil {
						log.Fatalf("Unable to echo: %s", err)
					}
				}()
			}
		}
	}()
	addr = l.Addr().String()
	return
}
