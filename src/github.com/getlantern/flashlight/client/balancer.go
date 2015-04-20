package client

import (
	"math"

	"github.com/getlantern/balancer"
	"github.com/getlantern/fronted"
)

// getBalancer waits for a message from client.balCh to arrive and then it
// writes it back to client.balCh before returning it as a value. This way we
// always have a balancer at client.balCh and, if we don't have one, it would
// block until one arrives.
func (client *Client) getBalancer() *balancer.Balancer {

	// This balChMu will protect balCh and ensure it always have, at most, one
	// element enqueued.
	client.balChMu.Lock()
	defer client.balChMu.Unlock()

	bal := <-client.balCh
	client.balCh <- bal

	return bal
}

// initBalancer takes hosts from cfg.FrontedServers and cfg.ChainedServers and
// it uses them to create a balancer. It also looks for the highest QOS dialer
// available among the fronted servers.
func (client *Client) initBalancer(cfg *ClientConfig) (*balancer.Balancer, fronted.Dialer) {
	var highestQOSFrontedDialer fronted.Dialer

	// The dialers slice must be large enough to handle all fronted and chained
	// servers.
	dialers := make([]*balancer.Dialer, 0, len(cfg.FrontedServers)+len(cfg.ChainedServers))

	// Adding fronted servers.
	log.Debugf("Adding %d domain fronted servers", len(cfg.FrontedServers))
	highestQOS := math.MinInt32
	for _, s := range cfg.FrontedServers {
		// Getting a dialer for domain fronting and a dialer to dial to arbitrary
		// addreses.
		fd, dialer := s.dialer(cfg.MasqueradeSets)
		dialers = append(dialers, dialer)
		if dialer.QOS > highestQOS {
			// If this dialer as a higher QOS than our current highestQOS, set it as
			// the highestQOSFrontedDialer.
			highestQOSFrontedDialer = fd
			highestQOS = dialer.QOS
		}
	}

	// Adding chained (CONNECT proxy) servers.
	log.Debugf("Adding %d chained servers", len(cfg.ChainedServers))
	for _, s := range cfg.ChainedServers {
		// Getting a dialer.
		dialer, err := s.Dialer()
		if err == nil {
			dialers = append(dialers, dialer)
		} else {
			log.Debugf("Unable to configure chained server for %s: %s", s.Addr)
		}
	}

	// Creating a balancer with all of our available dialers.
	bal := balancer.New(dialers...)

	// Locking balCh.
	client.balChMu.Lock()

	// Was the initBalancer called before?
	if client.balInitialized {
		// Yes, let's remove the old balancer.
		log.Trace("Draining balancer channel")
		old := <-client.balCh
		// Close old balancer on a goroutine to avoid blocking here
		go func() {
			old.Close()
			log.Debug("Closed old balancer")
		}()
	} else {
		// No, this is the first time.
		log.Trace("Creating balancer channel")
		client.balCh = make(chan *balancer.Balancer, 1)
	}

	// Publishing new balancer.
	log.Trace("Publishing balancer")

	// getBalancer() will be unblocked after this.
	client.balCh <- bal

	// Unlocking balCh.
	client.balChMu.Unlock()

	// Setting the balInitialized flag.
	client.balInitialized = true

	return bal, highestQOSFrontedDialer
}
