package listeners

import (
	"net"
	"net/http"
)

// Wrapped defaultConnListener that generates the wrapped defaultConn
type defaultConnListener struct {
	net.Listener
}

func NewDefaultListener(l net.Listener) net.Listener {
	return &defaultConnListener{l}
}

func (l *defaultConnListener) Accept() (c net.Conn, err error) {
	conn, err := l.Listener.Accept()
	if err != nil {
		return nil, err
	}

	return &defaultConn{
		WrapConnEmbeddable: nil,
		Conn:               conn,
	}, err
}

// Wrapped IdleTimingConn that supports OnState
type defaultConn struct {
	WrapConnEmbeddable
	net.Conn
}

func (c *defaultConn) OnState(s http.ConnState) {}

func (c *defaultConn) ControlMessage(msgType string, data interface{}) {}
