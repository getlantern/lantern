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

// Pool is a pool of connections. Connections are pooled lazily up to Size and
// expire after ClaimTimeout. Lazily here means that the Pool won't start to
// fill until the first request for a connection. As long as the Pool is
// actively being used, it will attempt to always have Size number of
// connections ready to use.
type Pool struct {
	// Size: while active, the pool will attempt to maintain at these many
	// connections.
	Size int

	// ClaimTimeout: connections will be removed from pool if unclaimed for
	// longer than ClaimTimeout. The default ClaimTimeout is 10 minutes. Once
	// connections have been removed from the Pool, they won't be replaced until
	// another connection is requested, at which point the pool will fill again.
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
	freshenCh  chan interface{}
	connCh     chan net.Conn
	stopCh     chan *sync.WaitGroup
}

// Start starts the pool, filling it to the Size and maintaining fresh
// connections.
func (p *Pool) Start() {
	p.runMutex.Lock()
	defer p.runMutex.Unlock()

	if p.running {
		log.Trace("Already running, ignoring additional Start() call")
		return
	}

	log.Debugf("Starting connection pool with size %d", p.Size)
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

	p.freshenCh = make(chan interface{}, p.Size)
	p.connCh = make(chan net.Conn)
	p.stopCh = make(chan *sync.WaitGroup, p.Size)

	log.Tracef("Remembering actual size %d in case Size is later changed", p.Size)
	p.actualSize = p.Size
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
	defer p.freshen()
	select {
	case conn := <-p.connCh:
		log.Trace("Using pooled conn")
		return conn, nil
	default:
		log.Trace("No pooled conn, dialing our own")
		return p.Dial()
	}
}

func (p *Pool) freshen() {
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

// feedConn works on continuously feeding the connCh with fresh connections.
func (p *Pool) feedConn() {
	newConnTimedOut := time.NewTimer(0)
	consecutiveDialFailures := time.Duration(0)
	nextDialAt := time.Now()

	for {
		select {
		case wg := <-p.stopCh:
			log.Trace("Stopped before next dial")
			wg.Done()
			return
		case <-p.freshenCh:
			delay := nextDialAt.Sub(time.Now())
			if delay > 0 {
				log.Tracef("Sleeping %s before dialing again", delay)
				time.Sleep(delay)
			}

			log.Trace("Dialing")
			conn, err := p.Dial()
			if err != nil {
				log.Tracef("Error dialing: %s", err)
				delay := consecutiveDialFailures * p.RedialDelayIncrement
				if delay > p.MaxRedialDelay {
					delay = p.MaxRedialDelay
				}
				nextDialAt = time.Now().Add(delay)
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
