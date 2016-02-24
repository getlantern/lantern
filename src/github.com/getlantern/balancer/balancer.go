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
	trustedDialersCount := 0

	bal := new(Balancer)

	bal.dialers = make([]*dialer, 0, len(dialers))

	for _, d := range dialers {
		dl := &dialer{Dialer: d}
		dl.start()
		bal.dialers = append(bal.dialers, dl)

		if dl.Trusted {
			trustedDialersCount++
		}
	}

	// Sort dialers by QOS (ascending) for later selection
	sort.Sort(byQOSAscending(bal.dialers))

	bal.trusted = make([]*dialer, 0, trustedDialersCount)

	for _, d := range bal.dialers {
		if d.Trusted {
			bal.trusted = append(bal.trusted, d)
		}
	}

	return bal
}

// AllAuthTokens() returns a list of all auth tokens for all dialers on this
// balancer.
func (b *Balancer) AllAuthTokens() []string {
	result := make([]string, 0, len(b.dialers))
	for i := 0; i < len(b.dialers); i++ {
		result = append(result, b.dialers[i].AuthToken)
	}
	return result
}

func (b *Balancer) dialerAndConn(network, addr string, targetQOS int) (*Dialer, net.Conn, error) {
	var dialers []*dialer

	_, port, _ := net.SplitHostPort(addr)

	// We try to identify HTTP traffic (as opposed to HTTPS) by port and only
	// send HTTP traffic to dialers marked as trusted.
	if port == "" || port == "80" || port == "8080" {
		dialers = b.trusted
		if len(b.trusted) == 0 {
			log.Error("No trusted dialers!")
		}
	} else {
		dialers = b.dialers
	}

	// To prevent dialing infinitely
	attempts := 3
	for i := 0; i < attempts; i++ {
		if len(dialers) == 0 {
			return nil, nil, fmt.Errorf("No dialers left to try on pass %v", i)
		}
		var d *dialer
		d, dialers = randomDialer(dialers, targetQOS)
		if d == nil {
			return nil, nil, fmt.Errorf("No dialers left on pass %v", i)
		}
		log.Debugf("Dialing %s://%s with %s", network, addr, d.Label)
		conn, err := d.Dial(network, addr)

		if err != nil {
			log.Errorf("Unable to dial via %v to %s://%s: %v on pass %v...continuing", d.Label, network, addr, err, i)
			d.onError(err)
			continue
		}
		log.Debugf("Successfully dialed via %v to %v://%v on pass %v", d.Label, network, addr, i)
		return d.Dialer, conn, nil
	}
	return nil, nil, fmt.Errorf("Still unable to dial %s://%s after %d attempts", network, addr, attempts)
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
	_, conn, err := b.dialerAndConn(network, addr, targetQOS)
	return conn, err
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
		log.Tracef("No dialers meet targetQOS %d, using those with highestQOS %d", targetQOS, highestQOS)
		filtered, _ = dialersMeetingQOS(dialers, highestQOS)
	}

	if len(filtered) == 0 {
		log.Debugf("No dialers meet targetQOS %d or highestQOS %d!", targetQOS, highestQOS)
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
			log.Tracef("Randomly selected dialer %s with weight %d, QOS %d", d.Label, d.Weight, d.QOS)
			// Leave at lest one dialer to try in next round
			if len(dialers) < 2 {
				return d, dialers
			} else {
				return d, withoutDialer(dialers, d)
			}
		}
	}

	// We should never reach this
	panic("No dialer found!")
}

func dialersMeetingQOS(dialers []*dialer, targetQOS int) ([]*dialer, int) {
	filtered := make([]*dialer, 0)
	highestQOS := 0
	for _, d := range dialers {
		/* Don't exclude inactive dialer as it's the only one we have
		if !d.isActive() {
			log.Trace("Excluding inactive dialer")
			continue
		}
		*/

		highestQOS = d.QOS // don't need to compare since dialers are already sorted by QOS (ascending)
		if d.QOS >= targetQOS {
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
