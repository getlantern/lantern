package main

import (
	"fmt"
	"github.com/getlantern/cloudflare"
	"io/ioutil"
	"net/http"
	"strings"
	"sync/atomic"
	"time"

	"github.com/getlantern/flashlight/client"
)

var (
	// Test hosts no faster than every 10 seconds
	hostTestRateLimit = 10 * time.Second

	maxFailuresToDeregister = 3
	backoffInterval         = 5 * time.Second
	maxBackoffWait          = hostTestRateLimit
)

// host represents a host entry in CloudFlare
type host struct {
	name string
	ip   string

	record     cloudflare.Record
	peers      *group
	fallbacks  *group
	roundrobin *group

	consecutiveFailures int32 // number of consecutive failures
}

func (h *host) run() {
	for {
		// Back off after consecutive failures
		cf := int(atomic.LoadInt32(&h.consecutiveFailures))
		bw := cf * cf * backoffInterval
		if bw > maxBackoffWait {
			bw = maxBackoffWait
		}
		time.Sleep(bw)

		// Attempt to proxy
		start := time.Now()
		log.Printf("Testing %v", h.name)
		err := AttemptToProxy(h.fullName(), "GET")
		if err != nil {
			log.Print(err)
			cf = atomic.AddInt32(&h.consecutiveFailures, 1)
			if cf == maxFailuresToDeregister {
				h.deregister()
			}
			continue
		}

		log.Printf("%v is able to proxy!", h.name)
		err = h.register()
		if err != nil {
			log.Error(err)
		}

		// Limit the rate at which we run successful tests
		time.Sleep(start.Add(hostTestRateLimit).Sub(time.Now()))
	}
}

func (h *host) register() error {
	log.Debugf("Regisering %v", h.name)

	err := registerHost()
	if err != nil {
		return fmt.Errorf("Unable to register host: %v", err)
	}
	err = registerRotations()
	if err != nil {
		return fmt.Errorf("Unable to register rotations: %v", err)
	}
	return nil
}

func (h *host) registerHost() error {
	rec, err := cf.Register(h.name, h.ip)
	if err == nil {
		h.record = rec
	}
	return err
}

func (h *host) registerRotations() error {
	if h.isFallback() {
		err := h.fallbacks.register(h)
		if err != nil {
			return err
		}
		return h.roundrobin.register(h)
	}
	return h.peers.register(h)
}

func (h *host) deregister() {
	log.Debugf("Deregistering %v", h.name)

	h.deregisterHost()
	h.deregisterRotations()
}

func (h *host) deregisterHost() {
	if h.record == nil {
		log.Tracef("Host not registered, no need to deregister: %v", h.name)
		return
	}

	err := util.Client.DestroyRecord(h.record.Domain, h.record.Id)
	if err != nil {
		log.Errorf("Unable to deregister host %v: %v", h.name, err)
		return
	}

	h.record = nil
}

func (h *host) deregisterRotations() {
	if h.isFallback() {
		h.fallbacks.deregister(h)
		h.roundrobin.deregister(h)
	} else {
		h.peers.deregister(h)
	}
}

func (h *host) fullName() string {
	return h.name + ".getiantem.org"
}

func (h *host) isFallback() bool {
	return isFallback(h.name)
}
