package main

import (
	"github.com/getlantern/go-dnsimple/dnsimple"
)

// dspGroup represents a host's participation in a rotation (e.g. roundrobin)
type dspGroup struct {
	subdomain string
	existing  *dnsimple.Record
}

func (g *dspGroup) String() string {
	return g.subdomain
}

// register registers a host with this dspGroup in DNSimple if it isn't
// already registered.
func (g *dspGroup) register(h *host) error {
	if g.existing != nil {
		log.Debugf("%v is already registered in DNSimple's %v, no need to re-register:", h, g.subdomain)
		return nil
	}
	log.Debugf("Registering to %v: %v", g.subdomain, h)

	var err error
	g.existing, err = dsputil.Register(g.subdomain, h.ip)
	return err
}

// deregister deregisters the host from this dspGroup in DNSimple if it is
// currently registered.
func (g *dspGroup) deregister(h *host) {
	if g.existing == nil {
		log.Tracef("%v is not registered in DNSimple's %v, no need to deregister", h, g.subdomain)
		return
	}

	log.Debugf("Deregistering from %v: %v", g.subdomain, h)

	// Destroy the record in the rotation...
	err := dsputil.DestroyRecord(g.existing)
	g.existing = nil

	if err != nil {
		log.Errorf("Unable to deregister host %v from DNSimple's rotation %v: %v", h, g.subdomain, err)
		return
	}
}
