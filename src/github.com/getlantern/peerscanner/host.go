package main

import (
	"crypto/tls"
	"fmt"
	"math"
	"math/rand"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/enproxy"
	"github.com/getlantern/tlsdialer"
)

var (
	// Set a short ttl on DNS entries
	ttl = 30 * time.Second

	// Test with a period of half the ttl
	testPeriod = ttl / 2

	dialTimeout    = 3 * time.Second
	requestTimeout = 6 * time.Second
	proxyAttempts  = 3

	terminateAfter = 20 * ttl

	testSites = []string{"www.google.com", "www.facebook.com", "www.youtube.com", "www.yahoo.com", "www.twitter.com", "www.live.com"}
)

// hostkey is a unique key for a host
type hostkey struct {
	name string // e.g. fl-singapore-004-1
	ip   string // e.g. 66.66.67.183
}

func (k hostkey) String() string {
	return fmt.Sprintf("%v (%v)", k.name, k.ip)
}

// host is an actor that represents a host entry in CloudFlare and is
// responsible for checking connectivity to the host and updating CloudFlare DNS
// accordingly.
type host struct {
	key    hostkey
	record *cloudflare.Record
	groups map[string]*group

	online            bool
	connectionRefused bool
	statusReady       sync.WaitGroup
	statusMutex       sync.RWMutex

	resetCh      chan interface{}
	unregisterCh chan interface{}

	proxiedClient *http.Client
}

// newHost creates a new host for the given name+ip and optional DNS record.
func newHost(key hostkey, record *cloudflare.Record) *host {
	h := &host{
		key:          key,
		record:       record,
		resetCh:      make(chan interface{}, 1),
		unregisterCh: make(chan interface{}, 1),
		proxiedClient: &http.Client{
			Transport: &http.Transport{
				Dial: func(network, addr string) (net.Conn, error) {
					return enproxy.Dial(addr, &enproxy.Config{
						DialProxy: func(addr string) (net.Conn, error) {
							return tlsdialer.DialWithDialer(&net.Dialer{
								Timeout: dialTimeout,
							}, "tcp", key.ip+":443", true, &tls.Config{
								InsecureSkipVerify: true,
							})
						},
					})
				},
			},
			Timeout: requestTimeout,
		},
	}

	if h.isFallback() {
		h.groups = map[string]*group{
			RoundRobin: &group{subdomain: RoundRobin},
			Fallbacks:  &group{subdomain: Fallbacks},
		}
	} else {
		h.groups = map[string]*group{
			Peers: &group{subdomain: Peers},
		}
	}
	h.statusReady.Add(1)

	return h
}

func (h *host) run() {
	go h.doRun()
}

func (h *host) doRun() {
	first := true
	lastSuccess := time.Now()
	lastTest := time.Now()
	periodTimer := time.NewTimer(0)
	terminateTimer := time.NewTimer(time.Duration(math.MaxInt32))

	for {
		if !first {
			// Limit the rate at which we run tests
			periodTimer.Reset(lastTest.Add(testPeriod).Sub(time.Now()))
			terminateTimer.Reset(lastSuccess.Add(terminateAfter).Sub(time.Now()))
		}

		select {
		case <-h.resetCh:
			// Host notified us of its presence
			lastSuccess = time.Now()
			lastTest = time.Time{}
		case <-h.unregisterCh:
		case <-terminateTimer.C:
			// Host notified us that it's gone
			// or testing has failed for a long time
			removeHost(h)
			h.deregister()
			return
		case <-periodTimer.C:
			// It's time to test again
			success, connectionRefused := h.isAbleToProxy()
			lastTest = time.Now()
			h.statusMutex.Lock()
			h.online, h.connectionRefused = success, connectionRefused
			h.statusMutex.Unlock()
			if first {
				h.statusReady.Done()
				first = false
			}
			if success {
				lastSuccess = time.Now()
				err := h.register()
				if err != nil {
					log.Error(err)
				}
			} else {
				h.deregister()
			}
		}
	}
}

func (h *host) status() (online bool, connectionRefused bool) {
	h.statusReady.Wait()
	h.statusMutex.RLock()
	defer h.statusMutex.RUnlock()
	return h.online, h.connectionRefused
}

func (h *host) reset() {
	select {
	case h.resetCh <- nil:
		log.Tracef("Resetting host %v", h.key)
	default:
		log.Tracef("Already resetting host %v, ignoring new request", h.key)
	}
}

func (h *host) unregister() {
	select {
	case h.unregisterCh <- nil:
		log.Tracef("Unregistering host %v", h.key)
	default:
		log.Tracef("Already unregistering host %v, ignoring new request", h.key)
	}
}

func (h *host) register() error {
	log.Debugf("Registering %v", h.key)

	err := h.registerHost()
	if err != nil {
		return fmt.Errorf("Unable to register host: %v", err)
	}
	err = h.registerGroups()
	if err != nil {
		return fmt.Errorf("Unable to register rotations: %v", err)
	}
	return nil
}

func (h *host) registerHost() error {
	rec, err := cfutil.Register(h.key.name, h.key.ip)
	if err == nil {
		h.record = rec
	}
	return err
}

func (h *host) registerGroups() error {
	for _, group := range h.groups {
		err := group.register(h)
		if err != nil {
			return err
		}
	}
	return nil
}

func (h *host) deregister() {
	log.Debugf("Deregistering %v", h.key)
	h.deregisterHost()
	h.deregisterGroups()
}

func (h *host) deregisterHost() {
	if h.record == nil {
		log.Tracef("Host not registered, no need to deregister: %v", h.key)
		return
	}

	if true {
		log.Debugf("Currently not deregistering hosts like %v", h.key)
		return
	}

	err := cfutil.Client.DestroyRecord(h.record.Domain, h.record.Id)
	if err != nil {
		log.Errorf("Unable to deregister host %v: %v", h.key, err)
		return
	}

	h.record = nil
}

func (h *host) deregisterGroups() {
	for _, group := range h.groups {
		group.deregister(h)
	}
}

func (h *host) fullName() string {
	return h.key.name + ".getiantem.org"
}

func (h *host) isFallback() bool {
	return isFallback(h.key.name)
}

func (h *host) isAbleToProxy() (bool, bool) {
	// Check whether or not we can proxy a few times
	for i := 0; i < proxyAttempts; i++ {
		success, connectionRefused := h.doIsAbleToProxy()
		if success || connectionRefused {
			// If we've succeeded, or our connection was flat-out refused, don't
			// bother trying to proxy again
			return success, connectionRefused
		}
	}
	return false, false
}

func (h *host) doIsAbleToProxy() (bool, bool) {
	// First just try a plain TCP connection. This is useful because the underlying
	// TCP-level error is consumed in the flashlight layer, and we need that
	// to be accessible on the client side in the logic for deciding whether
	// or not to display the port mapping message.
	conn, err := net.DialTimeout("tcp", h.key.ip+":443", dialTimeout)
	if err != nil {
		return false, strings.Contains(err.Error(), "connection refused")
	}
	conn.Close()

	// Now actually try to proxy an http request
	site := testSites[rand.Intn(len(testSites))]
	resp, err := h.proxiedClient.Head("http://" + site)
	if err != nil {
		log.Tracef("Unable to proxy to %v via %v", site, h.key.ip)
		return false, false
	}
	resp.Body.Close()
	if resp.StatusCode != 200 && resp.StatusCode != 301 {
		log.Tracef("Proxying to %v via %v returned unexpected status %d,", site, h.key.ip, resp.StatusCode)
		return false, false
	}
	return true, false
}
