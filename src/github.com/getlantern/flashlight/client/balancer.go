package client

import (
	"github.com/getlantern/balancer"
)

func (client *Client) getBalancer() *balancer.Balancer {
	bal := <-client.balCh
	client.balCh <- bal
	return bal
}

func (client *Client) initBalancer(cfg *ClientConfig) *balancer.Balancer {
	dialers := make([]*balancer.Dialer, 0, len(cfg.FrontedServers)+len(cfg.ChainedServers))

	log.Debugf("Adding %d domain fronted servers", len(cfg.FrontedServers))
	for _, s := range cfg.FrontedServers {
		dialer := s.dialer(cfg.MasqueradeSets)
		dialers = append(dialers, dialer)
	}

	log.Debugf("Adding %d chained servers", len(cfg.ChainedServers))
	for _, s := range cfg.ChainedServers {
		dialer, err := s.dialer()
		if err == nil {
			dialers = append(dialers, dialer)
		} else {
			log.Debugf("Unable to configure chained server for %s: %s", s.Addr)
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
	client.balInitialized = true

	return bal
}
