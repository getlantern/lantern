package connpool

import (
	"net"
	"sync"
	"time"

	"github.com/getlantern/golog"
)

const (
	DefaultClaimTimeout = 10 * time.Minute
)

var (
	log = golog.LoggerFor("connpool")
)

type DialFunc func() (net.Conn, error)

// Pool is a pool of connections, built from a Config using the New method. The
// purpose of connpool is to accelerate bursty clients, that is to say clients
// that tend to do a lot of dialing in rapid succeession. At steady state, the
// pool is usually empty, but once activity is detected it starts to fill itself
// up and keeps itself filled as long as activity continues.
//
// Connections are pooled lazily up to Size and expire after ClaimTimeout.
// Lazily here means that the Pool won't start to fill until the first request
// for a connection. As long as the Pool is actively being used, it will attempt
// to always have Size number of connections ready to use.
type Pool interface {
	// Get gets a connection from the pool, or dials a new one if none are
	// available.
	Get() (net.Conn, error)

	// Close stops the goroutines that are filling the pool, blocking until
	// they've all terminated.
	Close()
}

// Config contains configuration information for a Pool.
type Config struct {
	// Size: while active, the pool will attempt to maintain at these many
	// connections.
	Size int

	// ClaimTimeout: connections will be removed from pool if unclaimed for
	// longer than ClaimTimeout. The default ClaimTimeout is 10 minutes. Once
	// connections have been removed from the Pool, they won't be replaced until
	// another connection is requested, at which point the pool will fill again.
	ClaimTimeout time.Duration

	// Dial: specifies the function used to create new connections
	Dial DialFunc
}

type pool struct {
	Config

	runMutex  sync.Mutex
	running   bool
	freshenCh chan interface{}
	connCh    chan net.Conn
	stopCh    chan *sync.WaitGroup
}

// New creates and starts a Pool.
func New(cfg Config) Pool {
	p := &pool{
		Config:  cfg,
		running: true,
	}

	log.Debugf("Starting connection pool with size %d", p.Size)
	if p.ClaimTimeout == 0 {
		log.Tracef("Defaulting ClaimTimeout to %s", DefaultClaimTimeout)
		p.ClaimTimeout = DefaultClaimTimeout
	}

	p.freshenCh = make(chan interface{}, p.Size)
	p.connCh = make(chan net.Conn)
	p.stopCh = make(chan *sync.WaitGroup, p.Size)

	for i := 0; i < p.Size; i++ {
		go p.feedConn()
	}

	p.running = true
	return p
}

func (p *pool) Close() {
	p.runMutex.Lock()
	defer p.runMutex.Unlock()

	if !p.running {
		log.Trace("Not running, ignoring Stop() call")
		return
	}

	log.Trace("Stopping all feedConn goroutines")
	var wg sync.WaitGroup
	wg.Add(p.Size)
	for i := 0; i < p.Size; i++ {
		p.stopCh <- &wg
	}
	wg.Wait()

	p.running = false
}

func (p *pool) Get() (net.Conn, error) {
	log.Trace("Getting conn")
	select {
	case conn := <-p.connCh:
		log.Trace("Using pooled conn")
		p.freshen()
		return conn, nil
	default:
		log.Trace("No pooled conn, dialing our own")
		conn, err := p.Dial()
		if err == nil {
			log.Trace("Dial succeeded, freshening")
			p.freshen()
		} else {
			log.Trace("Dial failed, not bothering to freshen since subsequent dials may fail too")
		}
		return conn, err
	}
}

func (p *pool) freshen() {
	log.Trace("Freshen requested")

	freshened := 0
	for {
		select {
		case p.freshenCh <- nil:
			freshened += 1
		default:
			log.Tracef("No more to freshen, freshened %d connections", freshened)
			return
		}
	}
}

// feedConn works on feeding the connCh with fresh connections. For every
// request to freshen, it will dial once and make the connection available iff
// dialing succeeded. If the connection remains queued longer than
// p.ClaimTimeout, it will be closed.
func (p *pool) feedConn() {
	longDuration := 10 * 365 * 24 * time.Hour
	newConnTimedOut := time.NewTimer(longDuration)
	defer newConnTimedOut.Stop()

	for {
		select {
		case wg := <-p.stopCh:
			log.Trace("Stopped before next dial")
			wg.Done()
			return
		case <-p.freshenCh:
			log.Trace("Dialing")
			conn, err := p.Dial()
			if err != nil {
				log.Tracef("Error dialing: %s", err)
				continue
			}
			log.Trace("Dial successful")
			newConnTimedOut.Reset(p.ClaimTimeout)

			select {
			case p.connCh <- conn:
				// Reset timer so that it doesn't fire while we're waiting to freshen
				newConnTimedOut.Reset(longDuration)
				log.Trace("Fed conn")
			case <-newConnTimedOut.C:
				log.Trace("Queued conn timed out, closing")
				err := conn.Close()
				if err != nil {
					log.Tracef("Unable to close timed out queued conn: %s", err)
				}
			case wg := <-p.stopCh:
				log.Trace("Closing queued conn")
				err := conn.Close()
				if err != nil {
					log.Tracef("Unable to close queued conn: %s", err)
				}
				wg.Done()
				return
			}
		}
	}
}
