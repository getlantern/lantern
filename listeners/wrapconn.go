package listeners

import (
	"net"
	"net/http"
	"time"
)

// WrapConnEmbeddable can be embedded along net.Conn or not
type WrapConnEmbeddable interface {
	OnState(s http.ConnState)
	ControlMessage(msgType string, data interface{})
}

// WrapConn is an interface that describes a connection that an be wrapped and
// wrap other connections.  It responds to connection changes with OnState, and
// allows control messages with ControlMessage (for things like modify the
// connection at the wrapper level).
// It is important that these functions, when defined, pass the arguments
// to the wrapped connections.
type WrapConn interface {
	// net.Conn interface
	Read(b []byte) (n int, err error)
	Write(b []byte) (n int, err error)
	Close() error
	LocalAddr() net.Addr
	RemoteAddr() net.Addr
	SetDeadline(t time.Time) error
	SetReadDeadline(t time.Time) error
	SetWriteDeadline(t time.Time) error

	// Additional functionality
	OnState(s http.ConnState)
	ControlMessage(msgType string, data interface{})
}
