package client

import "github.com/getlantern/balancer"

// getBalancer waits for a message from client.balCh to arrive and then it
// writes it back to client.balCh before returning it as a value. This way we
// always have a balancer at client.balCh and, if we don't have one, it would
// block until one arrives.
func (client *Client) getBalancer() *balancer.Balancer {
	bal := <-client.balCh
	client.balCh <- bal
	return bal
}

// initBalancer takes hosts from cfg.FrontedServers and cfg.ChainedServers and
// it uses them to create a balancer. It also looks for the highest QOS dialer
// available among the fronted servers.
func (client *Client) initBalancer(cfg *ClientConfig) {
	//var highestQOSFrontedDialer fronted.Dialer

	// The dialers slice must be large enough to handle all fronted and chained
	// servers.
	dialers := make([]*balancer.Dialer, 0, len(cfg.FrontedServers)+len(cfg.ChainedServers))

	// Add fronted servers.
	/*
		log.Debugf("Adding %d domain fronted servers", len(cfg.FrontedServers))
		highestQOS := math.MinInt32
		for _, s := range cfg.FrontedServers {
			// Get a dialer for domain fronting (fd) and a dialer to dial to arbitrary
			// addreses (dialer).
			fd, dialer := s.dialer(cfg.MasqueradeSets)
			dialers = append(dialers, dialer)
			if dialer.QOS > highestQOS {
				// If this dialer as a higher QOS than our current highestQOS, set it as
				// the highestQOSFrontedDialer.
				highestQOSFrontedDialer = fd
				highestQOS = dialer.QOS
			}
		}
	*/

	// Add chained (CONNECT proxy) servers.
	log.Debugf("Adding %d chained servers", len(cfg.ChainedServers))
	if len(cfg.ChainedServers) == 0 {
		log.Error("NO CHAINED SERVERS!")
	}
	for _, s := range cfg.ChainedServers {
		dialer, err := s.Dialer()
		if err == nil {
			dialers = append(dialers, dialer)
		} else {
			log.Errorf("Unable to configure chained server. Received error: %v", err)
		}
	}

	bal := balancer.New(dialers...)

	if client.balInitialized {
		log.Trace("Draining balancer channel")
		old := <-client.balCh
		// Close old balancer on a goroutine to avoid blocking here
		go func() {
			old.Close()
			log.Debug("Closed old balancer")
		}()
	} else {
		log.Trace("Creating balancer channel")
		client.balCh = make(chan *balancer.Balancer, 1)
	}

	log.Trace("Publishing balancer")

	client.balCh <- bal

	// We don't need to protect client.balInitialized from race conditions
	// because it's only accessed here in initBalancer, which always gets called
	// under Configure, which never gets called concurrently with itself.
	client.balInitialized = true
}
