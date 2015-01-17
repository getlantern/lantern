package main

import (
	"fmt"
	"github.com/getlantern/cloudflare"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
	"sync/atomic"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/peerscanner/common"
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
		log.Printf("Testing %v", h.hostname())
		err := common.AttemptToProxy(h.fullHostname(), "GET")
		if err != nil {
			log.Print(err)
			cf = atomic.AddInt32(&h.consecutiveFailures, 1)
			if cf == maxFailuresToDeregister {
				h.deregister()
			}
			continue
		}

		log.Printf("%v is able to proxy!", h.hostname())
		h.registerIfNecessary()

		// Limit the rate at which we run successful tests
		time.Sleep(start.Add(hostTestRateLimit).Sub(time.Now()))
	}
}

func (h *host) register() {
	if h.isFallback() {
		h.fallbacks.register(h)
		h.roundrobin.register(h)
	} else {
		h.peers.register(h)
	}
}

func (h *host) deregister() {
	if h.isFallback() {
		h.fallbacks.deregister(h)
		h.roundrobin.deregister(h)
	} else {
		h.peers.deregister(h)
	}
}

func (h *host) hostname() string {
	return h.record.Name
}

func (h *host) fullHostname() string {
	return h.hostname() + ".getiantem.org"
}

func (h *host) isFallback() bool {
	return strings.HasPrefix(h.record.Name, "fl-")
}
