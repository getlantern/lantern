package client

import (
	"math"

	"github.com/getlantern/balancer"
	"github.com/getlantern/fronted"
	"github.com/getlantern/geolookup"
)

func (client *Client) getBalancer() *balancer.Balancer {
	bal := <-client.balCh
	client.balCh <- bal
	return bal
}

func (client *Client) initBalancer(cfg *ClientConfig) *balancer.Balancer {
	dialers := make([]*balancer.Dialer, 0, len(cfg.FrontedServers)+len(cfg.ChainedServers))

	log.Debugf("Adding %d domain fronted servers", len(cfg.FrontedServers))
	var highestQOSFrontedDialer fronted.Dialer
	highestQOS := math.MinInt32
	for _, s := range cfg.FrontedServers {
		fd, dialer := s.dialer(cfg.MasqueradeSets)
		dialers = append(dialers, dialer)
		if dialer.QOS > highestQOS {
			highestQOSFrontedDialer = fd
		}
	}

	if highestQOSFrontedDialer != nil {
		// This function will configure the HTTP client the geo package is going to
		// use.
		geolookup.SetHTTPClient(highestQOSFrontedDialer.DirectHttpClient())
	} else {
		log.Debugf("No fronted dialers found, unable to look up public ip")
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
