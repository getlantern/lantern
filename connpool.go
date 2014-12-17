package connpool

import (
	"net"
	"sync"
	"time"

	"github.com/getlantern/golog"
)

const (
	DefaultClaimTimeout         = 10 * time.Minute
	DefaultRedialDelayIncrement = 50 * time.Millisecond
	DefaultMaxRedialDelay       = 1 * time.Second
)

var (
	log = golog.LoggerFor("connpool")
)

type DialFunc func() (net.Conn, error)

// Pool is a pool of connections.  Connections are pooled eagerly up to MinSize
// and expire after ClaimTimeout.  Pool attempts to always have MinSize
// unexpired connections ready to go so that callers don't have to wait on a
// connection being established when they're ready to use it.
type Pool struct {
	// MinSize: the pool will always attempt to maintain at least these many
	// connections.
	MinSize int

	// ClaimTimeout: connections will be removed from pool if unclaimed for
	// longer than ClaimTimeout.  The default ClaimTimeout is 10 minutes.
	ClaimTimeout time.Duration

	// RedialDelayIncrement: amount by which to increase the redial delay with
	// each consecutive dial failure.
	RedialDelayIncrement time.Duration

	// MaxRedialDelay: the maximum amount of time to wait before redialing.
	MaxRedialDelay time.Duration

	// Dial: specifies the function used to create new connections
	Dial DialFunc

	runMutex   sync.Mutex
	running    bool
	actualSize int
	connCh     chan net.Conn
	stopCh     chan *sync.WaitGroup
}

// Start starts the pool, filling it to the MinSize and maintaining fresh
// connections.
func (p *Pool) Start() {
	p.runMutex.Lock()
	defer p.runMutex.Unlock()

	if p.running {
		log.Trace("Already running, ignoring additional Start() call")
		return
	}

	log.Trace("Starting connection pool")
	if p.ClaimTimeout == 0 {
		log.Tracef("Defaulting ClaimTimeout to %s", DefaultClaimTimeout)
		p.ClaimTimeout = DefaultClaimTimeout
	}
	if p.RedialDelayIncrement == 0 {
		log.Tracef("Defaulting p.RedialDelayIncrement to %s", DefaultRedialDelayIncrement)
		p.RedialDelayIncrement = DefaultRedialDelayIncrement
	}
	if p.MaxRedialDelay == 0 {
		log.Tracef("Defaulting p.MaxRedialDelay to %s", DefaultMaxRedialDelay)
		p.MaxRedialDelay = DefaultMaxRedialDelay
	}

	p.connCh = make(chan net.Conn)
	p.stopCh = make(chan *sync.WaitGroup, p.MinSize)

	log.Tracef("Remembering actual size %d in case MinSize is later changed", p.MinSize)
	p.actualSize = p.MinSize
	for i := 0; i < p.actualSize; i++ {
		go p.feedConn()
	}

	p.running = true
}

// Stop stops the goroutines that are filling the pool, blocking until they've
// all terminated.
func (p *Pool) Stop() {
	p.runMutex.Lock()
	defer p.runMutex.Unlock()

	if !p.running {
		log.Trace("Not running, ignoring Stop() call")
		return
	}

	log.Trace("Stopping all feedConn goroutines")
	var wg sync.WaitGroup
	wg.Add(p.actualSize)
	for i := 0; i < p.actualSize; i++ {
		p.stopCh <- &wg
	}
	wg.Wait()

	p.running = false
}

func (p *Pool) Get() (net.Conn, error) {
	log.Trace("Getting conn")
	select {
	case conn := <-p.connCh:
		log.Trace("Using pooled conn")
		return conn, nil
	default:
		log.Trace("No pooled conn, dialing our own")
		return p.Dial()
	}
}

// feedConn works on continuously feeding the connCh with fresh connections.
func (p *Pool) feedConn() {
	newConnTimedOut := time.NewTimer(0)
	consecutiveDialFailures := time.Duration(0)

	for {
		select {
		case wg := <-p.stopCh:
			log.Trace("Stopped before next dial")
			wg.Done()
			return
		default:
			log.Trace("Dialing")
			conn, err := p.Dial()
			if err != nil {
				log.Tracef("Error dialing: %s", err)
				delay := consecutiveDialFailures * p.RedialDelayIncrement
				if delay > p.MaxRedialDelay {
					delay = p.MaxRedialDelay
				}
				log.Tracef("Sleeping %s before dialing again", delay)
				time.Sleep(delay)
				consecutiveDialFailures = consecutiveDialFailures + 1
				continue
			}
			log.Trace("Dial successful")
			consecutiveDialFailures = 0
			newConnTimedOut.Reset(p.ClaimTimeout)

			select {
			case p.connCh <- conn:
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
