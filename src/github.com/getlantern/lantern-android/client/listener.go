package client

import (
	"errors"
	"net"
)

var (
	// ErrCouldNotCreateListener is returned when newListener fails.
	ErrCouldNotCreateListener = errors.New(`Could not create new listener.`)
	// errListenerClosed is returned when the server is closed.
	errListenerClosed = errors.New(`Server was manually closed.`)
)

// Listener is a wrapper around net.TCPListener that attempts to provide a
// Stop() function.
type listener struct {
	*net.TCPListener
	closed chan bool
}

// newListener creates a wrapper around TCPListener
func newListener(addr string) (wrap *listener, err error) {
	var li net.Listener
	var tli *net.TCPListener

	var ok bool

	if li, err = net.Listen("tcp", addr); err != nil {
		return nil, err
	}

	if tli, ok = li.(*net.TCPListener); !ok {
		return nil, ErrCouldNotCreateListener
	}

	wrap = &listener{
		TCPListener: tli,
		closed:      make(chan bool),
	}

	return wrap, nil
}

// Accept returns the next connection to the listener.
func (li *listener) Accept() (net.Conn, error) {
	for {
		select {
		case <-li.closed:
			return nil, errListenerClosed
		default:
			return li.TCPListener.Accept()
		}
	}
}

// Stop makees the listener stop accepting new connections and then kills all
// active connections.
func (li *listener) Stop() error {
	close(li.closed)
	li.Close()
	return nil
}
