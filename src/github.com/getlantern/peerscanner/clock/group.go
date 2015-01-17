package clock

// group represents a host's participation in a rotation (e.g. roundrobin)
type group struct {
	subdomain string
	existing  cloudflare.Record
}

// register registers a host with this group in CloudFlare if it isn't already
// registered.
func (g *group) register(h *host) {
	// Check to see if the host is already in the round robin before making a call
	// to the CloudFlare API.
	if g.existing != nil {
		log.Printf("%v already registered in %v", h.hostname(), g.subdomain)
		return
	}

	log.Printf("Registering to %s: %s", g.subdomain, h.hostname())
	cr := cloudflare.CreateRecord{Type: "A", Name: g.subdomain, Content: h.record.Value}
	rec, err := util.Client.CreateRecord(common.CF_DOMAIN, &cr)

	if err != nil {
		log.Printf("Could not register? : %s", err)
		return
	}

	// Note for some reason CloudFlare seems to ignore the TTL here.
	ur := cloudflare.UpdateRecord{Type: "A", Name: g.subdomain, Content: rec.Value, Ttl: "30", ServiceMode: "1"}

	err = util.Client.UpdateRecord(common.CF_DOMAIN, rec.Id, &ur)

	if err != nil {
		log.Printf("Could not register? : %s", err)
	}

	g.existing = rec
}

// deregister deregisters the host from this group in CloudFlare if is is
// currently registered
func (g *group) deregister(h *host) {
	if g.existing == nil {
		log.Printf("%v is not registered in %v", h.hostname(), g.subdomain)
		return
	}

	log.Printf("Unregistering from %v: %v", g.subdomain, h.hostname())

	// Destroy the record in the roundrobin...
	util.Client.DestroyRecord(existing.Domain, existing.Id)

	g.existing = nil
}
