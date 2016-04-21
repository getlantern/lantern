package main

import (
	"github.com/getlantern/cloudflare"
)

// cflGroup represents a host's participation in a rotation (e.g. roundrobin)
type cflGroup struct {
	subdomain  string
	existing   *cloudflare.Record
	isProxying bool
}

func (g *cflGroup) String() string {
	return g.subdomain
}

// register registers a host with this cflGroup in CloudFlare if it isn't
// already registered.
func (g *cflGroup) register(h *host) error {
	if g.isProxying {
		log.Debugf("%v is already registered in Cloudflare's %v, no need to re-register:", h, g.subdomain)
		return nil
	}
	log.Debugf("Registering to %v: %v", g.subdomain, h)

	var err error
	g.existing, g.isProxying, err = cflutil.EnsureRegistered(g.subdomain, h.ip, g.existing)
	return err
}

// deregister deregisters the host from this cflGroup in CloudFlare if it is
// currently registered.
func (g *cflGroup) deregister(h *host) {
	if g.existing == nil {
		log.Tracef("%v is not registered in Cloudflare's %v, no need to deregister", h, g.subdomain)
		return
	}

	log.Debugf("Deregistering from %v: %v", g.subdomain, h)

	// Destroy the record in the rotation...
	err := cflutil.DestroyRecord(g.existing)
	g.existing = nil
	g.isProxying = false

	if err != nil {
		log.Errorf("Unable to deregister host %v from Cloudflare's rotation %v: %v", h, g.subdomain, err)
		return
	}
}
