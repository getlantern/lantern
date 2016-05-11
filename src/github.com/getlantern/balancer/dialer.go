package balancer

import (
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/withtimeout"
)

// Dialer captures the configuration for dialing arbitrary addresses.
type Dialer struct {
	// Label: optional label with which to tag this dialer for debug logging.
	Label string

	// DialFN: this function dials the given network, addr.
	DialFN func(network, addr string) (net.Conn, error)

	// OnClose: (optional) callback for when this dialer is stopped.
	OnClose func()

	// Check: (optional) - a function that's used to test reachibility metrics
	// periodically or if the dialer was failed to connect.
	//
	// Checks are scheduled at exponentially increasing intervals that are
	// capped at 1 minute.
	//
	// If Check is not specified, a default Check will be used that makes an
	// HTTP request to http://www.google.com/humans.txt using this Dialer.
	Check func() bool

	// Determines whether a dialer can be trusted with unencrypted traffic.
	Trusted bool

	// Modifies any HTTP requests made using connections from this dialer.
	OnRequest func(req *http.Request)
}

var (
	maxCheckTimeout = 1 * time.Minute
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
	d.checkTimer = time.NewTimer(maxCheckTimeout)
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
				// We suspect that the check process may be causing users to get blacklisted.
				// At the moment, it's not strictly necessary and won't be until we do
				// multiple servers with pro, so let's skip it for now.
				// TODO: reenable for Pro if necessary
				if true {
					continue
				}
				log.Tracef("Start checking dialer %s", d.Label)
				ok := d.Check()
				if ok {
					d.markSuccess()
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
		d.updateEMADialTime(time.Now().Sub(t))
	}
	return conn, err
}

func (d *dialer) updateEMADialTime(t time.Duration) {
	// Ref dialer.EMADialTime() for the rationale.
	// The values is large enough to safely ignore decimals.
	newEMA := (atomic.LoadInt64(&d.emaDialTime) + t.Nanoseconds()) / 2
	log.Tracef("Dialer %s EMA(exponential moving average) dial time: %d", d.Label, newEMA)
	atomic.StoreInt64(&d.emaDialTime, newEMA)
}

func (d *dialer) markSuccess() {
	newCS := atomic.AddInt32(&d.consecSuccesses, 1)
	log.Tracef("Dialer %s consecutive successes: %d -> %d", d.Label, newCS-1, newCS)
	atomic.StoreInt32(&d.consecFailures, 0)
	d.muCheckTimer.Lock()
	d.checkTimer.Reset(maxCheckTimeout)
	d.muCheckTimer.Unlock()
}

func (d *dialer) markFailure() {
	atomic.StoreInt32(&d.consecSuccesses, 0)
	newCF := atomic.AddInt32(&d.consecFailures, 1)
	log.Tracef("Dialer %s consecutive failures: %d -> %d", d.Label, newCF-1, newCF)
	nextCheck := time.Duration(newCF*newCF) * 100 * time.Millisecond
	if nextCheck > maxCheckTimeout {
		nextCheck = maxCheckTimeout
	}
	d.muCheckTimer.Lock()
	d.checkTimer.Reset(nextCheck)
	d.muCheckTimer.Unlock()
}

func (d *dialer) defaultCheck() bool {
	client := &http.Client{
		Transport: &http.Transport{
			DisableKeepAlives: true,
			Dial:              d.dial,
		},
	}
	ok, timedOut, _ := withtimeout.Do(60*time.Second, func() (interface{}, error) {
		req, err := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
		if err != nil {
			log.Errorf("Could not create HTTP request?")
			return false, nil
		}
		if d.OnRequest != nil {
			d.OnRequest(req)
		}
		resp, err := client.Do(req)
		if err != nil {
			log.Debugf("Error testing dialer %s to humans.txt: %s", d.Label, err)
			return false, nil
		}
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
		log.Tracef("Tested dialer %s to humans.txt, status code %d", d.Label, resp.StatusCode)
		return resp.StatusCode == 200, nil
	})
	if timedOut {
		log.Errorf("Timed out checking dialer at: %v", d.Label)
	}
	return !timedOut && ok.(bool)
}
