// package balancer provides weighted round-robin load balancing of network
// connections with the ability to specify quality of service (QOS) levels.
package balancer

import (
	"fmt"
	"math/rand"
	"net"
	"sort"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("balancer")
)

var (
	emptyDialers = []*dialer{}
)

// Balancer balances connections established by one or more Dialers.
type Balancer struct {
	dialers []*dialer
	trusted []*dialer
}

// New creates a new Balancer using the supplied Dialers.
func New(dialers ...*Dialer) *Balancer {
	dhs := make([]*dialer, 0, len(dialers))

	for _, d := range dialers {
		dl := &dialer{Dialer: d}
		dl.start()
		dhs = append(dhs, dl)
	}

	// Sort dialers by QOS (ascending) for later selection
	sort.Sort(byQOSAscending(dhs))

	return &Balancer{
		dialers: dhs,
	}
}

// trustedDialers returns the subset of b.dialers that are considered as
// trusted.
func (b *Balancer) trustedDialers() []*dialer {
	if b.trusted == nil {
		b.trusted = make([]*dialer, 0, len(b.dialers))
		// Lazy initialization of trusted dialers.
		for _, d := range b.dialers {
			if d.Trusted {
				b.trusted = append(b.trusted, d)
			}
		}
	}
	return b.trusted
}

// DialQOS dials network, addr using one of the currently active configured
// Dialers. It attempts to use a Dialer whose QOS is higher than targetQOS, but
// will use the highest QOS Dialer(s) if none meet targetQOS. When multiple
// Dialers meet the targetQOS, load is distributed amongst them randomly based
// on their relative Weights.
//
// If a Dialer fails to connect, Dial will keep falling back through the
// remaining Dialers until it either manages to connect, or runs out of dialers
// in which case it returns an error.
func (b *Balancer) DialQOS(network, addr string, targetQOS int) (net.Conn, error) {
	var dialers []*dialer

	// Checking destination port.
	_, port, _ := net.SplitHostPort(addr)

	// Are we attempting to connect to port 80 (plain HTTP)?
	if port == "" || port == "80" {
		// Then try to use only a trusted dialer.
		dialers = b.trustedDialers()
		// Unless we don't have any...
		if len(dialers) == 0 {
			dialers = b.dialers
		}
	} else {
		// Use any dialer, encrypted traffic can hop travel safely through
		// untrusted nodes.
		dialers = b.dialers
	}

	for {
		if len(dialers) == 0 {
			return nil, fmt.Errorf("No dialers left to try")
		}
		var d *dialer
		d, dialers = randomDialer(dialers, targetQOS)
		if d == nil {
			return nil, fmt.Errorf("No dialers left")
		}
		if d.Label != "" {
			log.Debugf("Dialing %s://%s with %s", network, addr, d.Label)
		}
		conn, err := d.Dial(network, addr)
		if err != nil {
			log.Tracef("Unable to dial: %s", err)
			d.onError(err)
			continue
		}
		return conn, nil
	}

}

// Dial is like DialQOS with a targetQOS of 0.
func (b *Balancer) Dial(network, addr string) (net.Conn, error) {
	return b.DialQOS(network, addr, 0)
}

// Close closes this Balancer, stopping all background processing. You must call
// Close to avoid leaking goroutines.
func (b *Balancer) Close() {
	oldDialers := b.dialers
	b.dialers = nil
	for _, d := range oldDialers {
		d.stop()
	}
}

func randomDialer(dialers []*dialer, targetQOS int) (chosen *dialer, others []*dialer) {
	// Weed out inactive dialers and those with too low QOS
	filtered, highestQOS := dialersMeetingQOS(dialers, targetQOS)

	if len(filtered) == 0 {
		log.Trace("No dialers meet targetQOS, using those with highest QOS")
		filtered, _ = dialersMeetingQOS(dialers, highestQOS)
	}

	if len(filtered) == 0 {
		log.Trace("Still no dialers!")
		return nil, nil
	}

	totalWeights := 0
	for _, d := range filtered {
		totalWeights += d.Weight
	}

	// Pick a random server using a target value between 0 and the total weights
	t := rand.Intn(totalWeights)
	aw := 0
	for _, d := range filtered {
		aw += d.Weight
		if aw > t {
			log.Trace("Reached random target value, using this dialer")
			return d, withoutDialer(dialers, d)
		}
	}

	// We should never reach this
	panic("No dialer found!")
}

func dialersMeetingQOS(dialers []*dialer, targetQOS int) ([]*dialer, int) {
	filtered := make([]*dialer, 0)
	highestQOS := 0
	for _, d := range dialers {
		if !d.isActive() {
			log.Trace("Excluding inactive dialer")
			continue
		}

		highestQOS = d.QOS // don't need to compare since dialers are already sorted by QOS (ascending)
		if d.QOS >= targetQOS {
			log.Tracef("Including dialer with QOS %d meeting targetQOS %d", d.QOS, targetQOS)
			filtered = append(filtered, d)
		}
	}

	return filtered, highestQOS
}

func withoutDialer(dialers []*dialer, d *dialer) []*dialer {
	for i, existing := range dialers {
		if existing == d {
			return without(dialers, i)
		}
	}
	log.Tracef("Dialer not found for removal: %s", d)
	return dialers
}

func without(dialers []*dialer, i int) []*dialer {
	if len(dialers) == 1 {
		return emptyDialers
	} else if i == len(dialers)-1 {
		return dialers[:i]
	} else {
		c := make([]*dialer, len(dialers)-1)
		copy(c[:i], dialers[:i])
		copy(c[i:], dialers[i+1:])
		return c
	}
}

// byQOSAscending implements sort.Interface for []*dialer based on the QOS
// (ascending)
type byQOSAscending []*dialer

func (a byQOSAscending) Len() int           { return len(a) }
func (a byQOSAscending) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a byQOSAscending) Less(i, j int) bool { return a[i].QOS < a[j].QOS }
