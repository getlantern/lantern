package listeners

import (
	"errors"
	"math"
	"net"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("listeners")
)

type limitedListener struct {
	net.Listener

	maxConns    uint64
	numConns    uint64
	idleTimeout time.Duration

	stopped int32
	stop    chan bool
	restart chan bool
}

func NewLimitedListener(l net.Listener, maxConns uint64) net.Listener {
	if maxConns <= 0 {
		maxConns = math.MaxUint64
	}

	return &limitedListener{
		Listener:    l,
		stopped:     0,
		stop:        make(chan bool, 1),
		restart:     make(chan bool),
		maxConns:    maxConns,
		idleTimeout: 30 * time.Second,
	}
}

func (sl *limitedListener) Accept() (net.Conn, error) {
	select {
	case <-sl.stop:
		<-sl.restart
	default:
	}

	c, err := sl.Listener.Accept()
	if err != nil {
		return nil, err
	}

	atomic.AddUint64(&sl.numConns, 1)

	if log.IsTraceEnabled() {
		if sl.maxConns == math.MaxUint64 {
			log.Tracef("Accepted a new connection, %v in total now, of unlimited connections", sl.numConns)
		} else {
			log.Tracef("Accepted a new connection, %v in total now, %v max allowed", sl.numConns, sl.maxConns)
		}
	}

	sac, _ := c.(WrapConnEmbeddable)
	return &limitedConn{
		WrapConnEmbeddable: sac,
		Conn:               c,
		listener:           sl,
	}, err
}

func (sl *limitedListener) IsStopped() bool {
	return atomic.LoadInt32(&sl.stopped) == 1
}

func (sl *limitedListener) Stop() {
	if !sl.IsStopped() {
		sl.stop <- true
		atomic.StoreInt32(&sl.stopped, 1)
	}
}

func (sl *limitedListener) Restart() {
	if sl.IsStopped() {
		sl.restart <- true
		atomic.StoreInt32(&sl.stopped, 0)
	}
}

type limitedConn struct {
	WrapConnEmbeddable
	net.Conn
	listener *limitedListener
	closed   uint32
}

func (c *limitedConn) Close() (err error) {
	if atomic.SwapUint32(&c.closed, 1) == 1 {
		return errors.New("network connection already closed")
	}

	// Substract 1 by adding the two-complement of -1
	numConns := atomic.AddUint64(&c.listener.numConns, ^uint64(0))
	log.Tracef("Closed a connection and left %v remaining", numConns)
	return c.Conn.Close()
}

func (c *limitedConn) OnState(s http.ConnState) {
	l := c.listener
	if log.IsTraceEnabled() {
		if l.maxConns == math.MaxUint64 {
			log.Tracef("OnState(%s), numConns = %v, of unlimited connections", s, l.numConns)
		} else {
			log.Tracef("OnState(%s), numConns = %v, maxConns = %v", s, l.numConns, l.maxConns)
		}
	}

	if s == http.StateNew {
		if atomic.LoadUint64(&l.numConns) >= l.maxConns {
			if log.IsTraceEnabled() {
				if l.maxConns == math.MaxUint64 {
					log.Tracef("numConns %v (unlimited connections), stop accepting new connections", l.numConns)
				} else {
					log.Tracef("numConns %v >= maxConns %v, stop accepting new connections", l.numConns, l.maxConns)
				}
			}
			l.Stop()
		} else if l.IsStopped() {
			if log.IsTraceEnabled() {
				if l.maxConns == math.MaxUint64 {
					log.Tracef("numConns %v < maxConns (unlimited connections), accept new connections again", l.numConns)
				} else {
					log.Tracef("numConns %v < maxConns %v, accept new connections again", l.numConns, l.maxConns)
				}
			}
			l.Restart()
		}
	}

	// Pass down to wrapped connections
	if c.WrapConnEmbeddable != nil {
		c.WrapConnEmbeddable.OnState(s)
	}
}

func (c *limitedConn) ControlMessage(msgType string, data interface{}) {
	// Simply pass down the control message to the wrapped connection
	if c.WrapConnEmbeddable != nil {
		c.WrapConnEmbeddable.ControlMessage(msgType, data)
	}
}
