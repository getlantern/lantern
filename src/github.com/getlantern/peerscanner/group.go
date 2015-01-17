package main

import (
	"./cf"
)

// group represents a host's participation in a rotation (e.g. roundrobin)
type group struct {
	subdomain string
	existing  cloudflare.Record
}

// register registers a host with this group in CloudFlare if it isn't already
// registered.
func (g *group) register(h *host) error {
	rec, err := cf.Register(g.subdomain, h.ip)
	if err == nil {
		g.existing = rec
	}
	return err
}

// deregister deregisters the host from this group in CloudFlare if is is
// currently registered
func (g *group) deregister(h *host) {
	if g.existing == nil {
		log.Tracef("%v is not registered in %v", h.name, g.subdomain)
		return
	}

	log.Tracef("Unregistering from %v: %v", g.subdomain, h.name)

	// Destroy the record in the roundrobin...
	err := util.Client.DestroyRecord(g.existing.Domain, g.existing.Id)
	if err != nil {
		log.Errorf("Unable to deregister host %v from rotation %v: %v", h.name, g.subdomain, err)
		return
	}

	g.existing = nil
}
