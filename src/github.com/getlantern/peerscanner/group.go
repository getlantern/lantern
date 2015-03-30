package main

import (
	"github.com/getlantern/cloudflare"
)

// group represents a host's participation in a rotation (e.g. roundrobin)
type group struct {
	subdomain  string
	existing   *cloudflare.Record
	isProxying bool
}

func (g *group) String() string {
	return g.subdomain
}

// register registers a host with this group in CloudFlare if it isn't already
// registered.
func (g *group) register(h *host) error {
	if g.isProxying {
		log.Debugf("%v is already registered in %v, no need to re-register:", h, g.subdomain)
		return nil
	}
	log.Debugf("Registering to %v: %v", g.subdomain, h)

	var err error
	g.existing, g.isProxying, err = cfutil.EnsureRegistered(g.subdomain, h.ip, g.existing)
	return err
}

// deregister deregisters the host from this group in CloudFlare if it is
// currently registered.
func (g *group) deregister(h *host) {
	if g.existing == nil {
		log.Tracef("%v is not registered in %v, no need to deregister", h, g.subdomain)
		return
	}

	log.Debugf("Deregistering from %v: %v", g.subdomain, h)

	// Destroy the record in the rotation...
	err := cfutil.DestroyRecord(g.existing)
	g.existing = nil
	g.isProxying = false

	if err != nil {
		log.Errorf("Unable to deregister host %v from rotation %v: %v", h, g.subdomain, err)
		return
	}
}
