package balancer

import (
	"math/rand"
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

// Dialer captures the configuration for dialing arbitrary addresses.
type Dialer struct {
	// Label: optional label with which to tag this dialer for debug logging.
	Label string

	// DialFN: this function dials the given network, addr.
	DialFN func(network, addr string) (net.Conn, error)

	// OnClose: (optional) callback for when this dialer is stopped.
	OnClose func()

	// Check: - a function that's used to test reachibility metrics
	// periodically or if the dialer was failed to connect.
	//
	// Checks are scheduled at exponentially increasing intervals that are
	// capped at MaxCheckTimeout ± ½.
	Check func() bool

	// Determines whether a dialer can be trusted with unencrypted traffic.
	Trusted bool

	// Modifies any HTTP requests made using connections from this dialer.
	OnRequest func(req *http.Request)
}

var (
	// MaxCheckTimeout is the average of maximum wait time before checking an idle or
	// failed dialer. The real cap is a random duration between MaxCheckTimeout ± ½.
	MaxCheckTimeout = 1 * time.Minute
)

type dialer struct {
	// Ref dialer.EMADialTime() for the rationale
	// Keep it at the top to make sure 64-bit alignment, see
	// https://golang.org/pkg/sync/atomic/#pkg-note-BUG
	emaDialTime int64

	*Dialer
	closeCh      chan struct{}
	muCheckTimer sync.Mutex
	checkTimer   *time.Timer

	consecSuccesses int32
	consecFailures  int32
}

func (d *dialer) Start() {
	d.consecSuccesses = 1 // be optimistic
	d.closeCh = make(chan struct{})
	d.checkTimer = time.NewTimer(maxCheckTimeout())
	if d.Check == nil {
		d.Check = d.defaultCheck
	}

	go func() {
		for {
			select {
			case <-d.closeCh:
				log.Tracef("Dialer %s stopped", d.Label)
				if d.OnClose != nil {
					d.OnClose()
				}
				return
			case <-d.checkTimer.C:
				log.Tracef("Start checking dialer %s", d.Label)
				t := time.Now()
				ok := d.Check()
				if ok {
					d.markSuccess()
					// Check time is generally larger than dial time, but still
					// meaningful when comparing latency across multiple
					// dialers.
					d.updateEMADialTime(time.Since(t))
				} else {
					d.markFailure()
				}
			}
		}
	}()
}

func (d *dialer) Stop() {
	d.closeCh <- struct{}{}
}

// It's the Exponential moving average of dial time with an α of 0.5.
// Ref https://en.wikipedia.org/wiki/Moving_average#Exponential_moving_average.
// If it's not smooth enough, we can increase α by changing `updateEMADialTime`.
func (d *dialer) EMADialTime() int64 {
	return atomic.LoadInt64(&d.emaDialTime)
}
func (d *dialer) ConsecSuccesses() int32 {
	return atomic.LoadInt32(&d.consecSuccesses)
}
func (d *dialer) ConsecFailures() int32 {
	return atomic.LoadInt32(&d.consecFailures)
}

func (d *dialer) dial(network, addr string) (net.Conn, error) {
	t := time.Now()
	conn, err := d.DialFN(network, addr)
	if err != nil {
		d.markFailure()
	} else {
		d.markSuccess()
		d.updateEMADialTime(time.Since(t))
	}
	return conn, err
}

func (d *dialer) updateEMADialTime(t time.Duration) {
	// Ref dialer.EMADialTime() for the rationale.
	// The values is large enough to safely ignore decimals.
	newEMA := (atomic.LoadInt64(&d.emaDialTime) + t.Nanoseconds()) / 2
	log.Tracef("Dialer %s EMA(exponential moving average) dial time: %v", d.Label, time.Duration(newEMA))
	atomic.StoreInt64(&d.emaDialTime, newEMA)
}

func (d *dialer) markSuccess() {
	newCS := atomic.AddInt32(&d.consecSuccesses, 1)
	log.Tracef("Dialer %s consecutive successes: %d -> %d", d.Label, newCS-1, newCS)
	atomic.StoreInt32(&d.consecFailures, 0)
	d.muCheckTimer.Lock()
	d.checkTimer.Reset(maxCheckTimeout())
	d.muCheckTimer.Unlock()
}

func (d *dialer) markFailure() {
	atomic.StoreInt32(&d.consecSuccesses, 0)
	newCF := atomic.AddInt32(&d.consecFailures, 1)
	log.Tracef("Dialer %s consecutive failures: %d -> %d", d.Label, newCF-1, newCF)
	nextCheck := time.Duration(newCF*newCF) * 100 * time.Millisecond
	if nextCheck > MaxCheckTimeout {
		nextCheck = maxCheckTimeout()
	}
	d.muCheckTimer.Lock()
	d.checkTimer.Reset(nextCheck)
	d.muCheckTimer.Unlock()
}

func (d *dialer) defaultCheck() bool {
	log.Errorf("No check function provided for dialer %s", d.Label)
	return false
}

// adds randomization to make requests less distinguishable on the network.
func maxCheckTimeout() time.Duration {
	return time.Duration((MaxCheckTimeout.Nanoseconds() / 2) + rand.Int63n(MaxCheckTimeout.Nanoseconds()))
}
