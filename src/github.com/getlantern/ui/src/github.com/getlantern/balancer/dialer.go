package balancer

import (
	"net"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/getlantern/withtimeout"
)

// Dialer captures the configuration for dialing arbitrary addresses.
type Dialer struct {
	// Label: optional label with which to tag this dialer for debug logging.
	Label string

	// Weight: determines how often this Dialer is used relative to the other
	// Dialers on the balancer.
	Weight int

	// QOS: identifies the quality of service provided by this dialer. Higher
	// numbers equal higher quality. "Quality" in this case is loosely defined,
	// but can mean things such as reliability, speed, etc.
	QOS int

	// Dial: this function dials the given network, addr.
	Dial func(network, addr string) (net.Conn, error)

	// OnClose: (optional) callback for when this dialer is stopped.
	OnClose func()

	// Check: (optional) - When dialing fails, this Dialer is deactivated (taken
	// out of rotation). Check is a function that's used periodically after a
	// failed dial to check whether or not Dial works again. As soon as there is
	// a successful check, this Dialer will be activated (put back in rotation).
	//
	// If Check is not specified, a default Check will be used that makes an
	// HTTP request to http://www.google.com/humans.txt using this Dialer.
	//
	// Checks are scheduled at exponentially increasing intervals that are
	// capped at 1 minute.
	Check func() bool
}

var (
	longDuration    = 1000000 * time.Hour
	maxCheckTimeout = 5 * time.Second
)

type dialer struct {
	*Dialer
	active int32
	errCh  chan time.Time
}

func (d *dialer) start() {
	d.active = 1
	d.errCh = make(chan time.Time, 1)
	if d.Check == nil {
		d.Check = d.defaultCheck
	}

	go func() {
		lastFailed := time.Time{}
		lastCheckSucceeded := time.Time{}
		consecCheckFailures := 0
		timer := time.NewTimer(longDuration)

		for {
			if lastFailed.After(lastCheckSucceeded) {
				atomic.StoreInt32(&d.active, 0)
				log.Trace("Inactive, scheduling check")
				timeout := time.Duration(consecCheckFailures*consecCheckFailures) * 100 * time.Millisecond
				timer.Reset(timeout)
			} else {
				atomic.StoreInt32(&d.active, 1)
				log.Trace("Active")
			}
			select {
			case t, ok := <-d.errCh:
				if !ok {
					log.Trace("dialer stopped")
					if d.OnClose != nil {
						d.OnClose()
					}
					return
				}
				lastFailed = t
			case <-timer.C:
				ok := d.Check()
				if ok {
					lastCheckSucceeded = time.Now()
					timer.Reset(longDuration)
				} else {
					consecCheckFailures += 1
				}
			}
		}
	}()
}

func (d *dialer) isActive() bool {
	return atomic.LoadInt32(&d.active) == 1
}

func (d *dialer) onError(err error) {
	select {
	case d.errCh <- time.Now():
		log.Trace("Error reported")
	default:
		log.Trace("Errors already pending, ignoring new one")
	}
}

func (d *dialer) stop() {
	close(d.errCh)
}

func (d *dialer) defaultCheck() bool {
	client := &http.Client{
		Transport: &http.Transport{
			Dial: d.Dial,
		},
	}
	ok, timedOut, _ := withtimeout.Do(10*time.Second, func() (interface{}, error) {
		resp, err := client.Get("http://www.google.com/humans.txt")
		if err != nil {
			log.Debugf("Error on testing humans.txt: %s", err)
			return false, nil
		}
		resp.Body.Close()
		return resp.StatusCode == 200, nil
	})
	return !timedOut && ok.(bool)
}
