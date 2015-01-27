package client

import (
	"errors"
	"net"
)

var (
	// ErrCouldNotCreateListener is returned when NewListener fails.
	ErrCouldNotCreateListener = errors.New(`Could not create new listener.`)
	// ErrClosed is returned when the server is closed.
	ErrClosed = errors.New(`Server was manually closed.`)
)

// Listener is a wrapper around net.TCPListener that attempts to provide a
// Stop() function.
type Listener struct {
	*net.TCPListener
	closed chan bool
}

// NewListener creates a wrapper around TCPListener
func NewListener(addr string) (wrap *Listener, err error) {
	var li net.Listener
	var tli *net.TCPListener

	var ok bool

	if li, err = net.Listen("tcp", addr); err != nil {
		return nil, err
	}

	if tli, ok = li.(*net.TCPListener); !ok {
		return nil, ErrCouldNotCreateListener
	}

	wrap = &Listener{
		TCPListener: tli,
		closed:      make(chan bool),
	}

	return wrap, nil
}

// Accept returns the next connection to the listener.
func (li *Listener) Accept() (net.Conn, error) {
	for {
		select {
		case <-li.closed:
			return nil, ErrClosed
		default:
			return li.TCPListener.Accept()
		}
	}
}

// Stop makees the listener stop accepting new connections and then kills all
// active connections.
func (li *Listener) Stop() error {
	close(li.closed)
	li.Close()
	return nil
}
