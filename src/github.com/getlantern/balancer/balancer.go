// Package balancer provides load balancing of network connections per different
// strategies.
package balancer

import (
	"container/heap"
	"fmt"
	"net"
	"net/http"
	"sync"

	"github.com/getlantern/golog"
)

const (
	dialAttempts = 3
)

var (
	log = golog.LoggerFor("balancer")
)

// Balancer balances connections established by one or more Dialers.
type Balancer struct {
	mu      sync.RWMutex
	dialers dialerHeap
	trusted dialerHeap
}

// New creates a new Balancer using the supplied Strategy and Dialers.
func New(st Strategy, dialers ...*Dialer) *Balancer {
	var dls []*dialer
	var tdls []*dialer

	for _, d := range dialers {
		dl := &dialer{Dialer: d}
		dl.Start()
		dls = append(dls, dl)

		if dl.Trusted {
			tdls = append(tdls, dl)
		}
	}

	bal := &Balancer{dialers: st(dls), trusted: st(tdls)}
	heap.Init(&bal.dialers)
	heap.Init(&bal.trusted)
	return bal
}

// OnRequest calls Dialer.OnRequest for every dialer in this balancer.
func (b *Balancer) OnRequest(req *http.Request) {
	b.mu.RLock()
	b.dialers.onRequest(req)
	b.mu.RUnlock()
}

// Dial dials (network, addr) using one of the currently active configured
// Dialers. The Dialer to choose depends on the Strategy when creating the
// balancer. Only Trusted Dialers are used to dial HTTP hosts.
//
// If a Dialer fails to connect, Dial will keep trying at most 3 times until it
// either manages to connect, or runs out of dialers in which case it returns an
// error.
func (b *Balancer) Dial(network, addr string) (net.Conn, error) {
	var dialers dialerHeap

	_, port, _ := net.SplitHostPort(addr)

	// We try to identify HTTP traffic (as opposed to HTTPS) by port and only
	// send HTTP traffic to dialers marked as trusted.
	if port == "" || port == "80" || port == "8080" {
		if b.trusted.Len() == 0 {
			return nil, fmt.Errorf("No trusted dialers!")
		}
		dialers = b.trusted
	} else {
		dialers = b.dialers
	}

	for i := 0; i < dialAttempts; i++ {
		if dialers.Len() == 0 {
			return nil, fmt.Errorf("No dialers left to try on pass %v", i)
		}
		b.mu.Lock()
		// heap will re-adjust based on new metrics
		d := heap.Pop(&dialers).(*dialer)
		heap.Push(&dialers, d)
		b.mu.Unlock()
		log.Debugf("Dialing %s://%s with %s", network, addr, d.Label)
		conn, err := d.dial(network, addr)
		if err != nil {
			log.Errorf("Unable to dial via %v to %s://%s: %v on pass %v...continuing", d.Label, network, addr, err, i)
			continue
		}
		log.Debugf("Successfully dialed via %v to %v://%v on pass %v", d.Label, network, addr, i)
		return conn, nil
	}
	return nil, fmt.Errorf("Still unable to dial %s://%s after %d attempts", network, addr, dialAttempts)
}

// Close closes this Balancer, stopping all background processing. You must call
// Close to avoid leaking goroutines.
func (b *Balancer) Close() {
	oldDialers := b.dialers
	b.dialers.dialers = nil
	for _, d := range oldDialers.dialers {
		d.Stop()
	}
}
