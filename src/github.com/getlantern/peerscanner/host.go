package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"math/rand"
	"net"
	"net/http"
	"strings"
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

	// If we haven't had a successul test or reset after this amount of time,
	// terminate.
	terminateAfter = 10 * time.Minute

	dialTimeout    = 3 * time.Second // how long to wait on connecting to host
	requestTimeout = 6 * time.Second // how long to wait for test requests to process
	proxyAttempts  = 3               // how many times to try a test request before considering host down

	// Sites to use for testing connectivity. WARNING - these should only be
	// sites with consistent fast response times, around the world, otherwise
	// tests may time out.
	testSites = []string{"www.google.com", "www.youtube.com", "www.facebook.com"}
)

type status struct {
	online            bool
	connectionRefused bool
}

// host is an actor that represents a host entry in CloudFlare and is
// responsible for checking connectivity to the host and updating CloudFlare DNS
// accordingly.
type host struct {
	name   string
	ip     string
	record *cloudflare.Record
	groups map[string]*group

	resetCh      chan string
	unregisterCh chan interface{}
	statusCh     chan chan *status

	proxiedClient *http.Client
}

func (h *host) String() string {
	return fmt.Sprintf("%v (%v)", h.name, h.ip)
}

// newHost creates a new host for the given name, ip and optional DNS record.
func newHost(name string, ip string, record *cloudflare.Record) *host {
	// Cache TLS sessions
	clientSessionCache := tls.NewLRUClientSessionCache(1000)

	h := &host{
		name:         name,
		ip:           ip,
		record:       record,
		resetCh:      make(chan string, 1000),
		unregisterCh: make(chan interface{}, 1),
		statusCh:     make(chan chan *status, 1000),
		proxiedClient: &http.Client{
			Transport: &http.Transport{
				Dial: func(network, addr string) (net.Conn, error) {
					return enproxy.Dial(addr, &enproxy.Config{
						DialProxy: func(addr string) (net.Conn, error) {
							return tlsdialer.DialWithDialer(&net.Dialer{
								Timeout: dialTimeout,
							}, "tcp", ip+":443", true, &tls.Config{
								InsecureSkipVerify: true,
								ClientSessionCache: clientSessionCache,
							})
						},
						NewRequest: func(upstreamHost string, method string, body io.Reader) (req *http.Request, err error) {
							return http.NewRequest(method, "http://"+ip+"/", body)
						},
					})
				},
				DisableKeepAlives: true,
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

	return h
}

// run starts the main run loop for this host on a goroutine
func (h *host) run() {
	go h.doRun()
}

func (h *host) doRun() {
	first := true
	lastSuccess := time.Now()
	lastTest := time.Now()
	periodTimer := time.NewTimer(0)
	terminateTimer := time.NewTimer(0)

	for {
		if !first {
			// Limit the rate at which we run tests
			periodTimer.Reset(lastTest.Add(testPeriod).Sub(time.Now()))
		}

		// Terminate run loop after some largish amount of time
		terminateTimer.Reset(lastSuccess.Add(terminateAfter).Sub(time.Now()))

		select {
		case newName := <-h.resetCh:
			log.Tracef("Host notified us of its presence")
			lastSuccess = time.Now()
			lastTest = time.Time{}
			if newName != h.name {
				log.Debugf("Hostname for %v changed to %v", h, newName)
				if h.record != nil {
					log.Debugf("Deregistering old hostname %v", h.name)
					h.doDeregisterHost()
				}
				h.name = newName
			}
		case <-h.unregisterCh:
			log.Debugf("Unregistering %v and terminating", h)
			h.terminate()
			return
		case <-terminateTimer.C:
			log.Debugf("%v had no successful checks or resets in %v, terminating", h, terminateAfter)
			h.terminate()
			return
		case <-periodTimer.C:
			online, connectionRefused, err := h.isAbleToProxy()
			h.reportStatus(online, connectionRefused)
			lastTest = time.Now()
			first = false
			if online {
				log.Tracef("Test for %v successful", h)
				lastSuccess = time.Now()
				err := h.register()
				if err != nil {
					log.Error(err)
				}
			} else {
				log.Tracef("Test for %v failed with error: %v", h, err)
				// Deregister this host from its rotations. We leave the host
				// itself registered to support continued sticky routing in case
				// any clients still have connections open to it.
				h.deregisterFromRotations()
			}
		}
	}
}

// status returns the status of this host as of the next scheduled check
func (h *host) status() (online bool, connectionRefused bool) {
	sch := make(chan *status)
	h.statusCh <- sch
	s := <-sch
	return s.online, s.connectionRefused
}

// reportStatus reports the given status back to any callers that are waiting
// for it.
func (h *host) reportStatus(online bool, connectionRefused bool) {
	s := &status{online, connectionRefused}
	for {
		select {
		case sch := <-h.statusCh:
			sch <- s
		default:
			return
		}
	}
}

// reset resets this host's run loop in response to the host having reported in,
// which can include changing the name if the given name is new.
func (h *host) reset(name string) {
	h.resetCh <- name
}

// unregister unregisters this host in response to the host having requested
// unregistration.
func (h *host) unregister() {
	select {
	case h.unregisterCh <- nil:
		log.Tracef("Unregistering host %v", h)
	default:
		log.Tracef("Already unregistering host %v, ignoring new request", h)
	}
}

/*******************************************************************************
 * Functions for managing DNS
 ******************************************************************************/

// terminate cleans up DNS on termination of this host's run loop
func (h *host) terminate() {
	removeHost(h)
	h.deregister()
}

func (h *host) register() error {
	err := h.registerHost()
	if err != nil && !isDuplicateError(err) {
		return fmt.Errorf("Unable to register host: %v", err)
	}
	err = h.registerToRotations()
	if err != nil {
		return fmt.Errorf("Unable to register rotations: %v", err)
	}
	return nil
}

func (h *host) registerHost() error {
	if h.record != nil {
		log.Tracef("Host already registered, no need to re-register: %v", h)
		return nil
	}

	log.Debugf("Registering %v", h)

	rec, err := cfutil.Register(h.name, h.ip)
	if err == nil {
		h.record = rec
	}
	return err
}

func (h *host) registerToRotations() error {
	for _, group := range h.groups {
		err := group.register(h)
		if err != nil && !isDuplicateError(err) {
			return err
		}
	}
	return nil
}

func (h *host) deregister() {
	h.deregisterHost()
	h.deregisterFromRotations()
}

func (h *host) deregisterHost() {
	if h.record == nil {
		log.Tracef("Host not registered, no need to deregister: %v", h)
		return
	}

	if h.isFallback() {
		log.Debugf("Currently not deregistering fallbacks like %v", h)
		return
	}

	log.Debugf("Deregistering %v", h)
	h.doDeregisterHost()
}

func (h *host) doDeregisterHost() {
	err := cfutil.DestroyRecord(h.record)
	if err != nil {
		log.Errorf("Unable to deregister host %v: %v", h, err)
		return
	}

	h.record = nil
}

func (h *host) deregisterFromRotations() {
	for _, group := range h.groups {
		group.deregister(h)
	}
}

func (h *host) fullName() string {
	return h.name + ".getiantem.org"
}

func (h *host) isFallback() bool {
	return isFallback(h.name)
}

func (h *host) isAbleToProxy() (bool, bool, error) {
	// Check whether or not we can proxy a few times
	var lastErr error
	for i := 0; i < proxyAttempts; i++ {
		success, connectionRefused, err := h.doIsAbleToProxy()
		if err != nil {
			log.Trace(err.Error())
		}
		lastErr = err
		if success || connectionRefused {
			// If we've succeeded, or our connection was flat-out refused, don't
			// bother trying to proxy again
			return success, connectionRefused, lastErr
		}
	}
	return false, false, lastErr
}

func (h *host) doIsAbleToProxy() (bool, bool, error) {
	// First just try a plain TCP connection. This is useful because the underlying
	// TCP-level error is consumed in the flashlight layer, and we need that
	// to be accessible on the client side in the logic for deciding whether
	// or not to display the port mapping message.
	addr := h.ip + ":443"
	conn, err := net.DialTimeout("tcp", addr, dialTimeout)
	if err != nil {
		err2 := fmt.Errorf("Unable to connect to %v: %v", addr, err)
		return false, strings.Contains(err.Error(), "connection refused"), err2
	}
	conn.Close()

	// Now actually try to proxy an http request
	site := testSites[rand.Intn(len(testSites))]
	resp, err := h.proxiedClient.Head("http://" + site)
	if err != nil {
		return false, false, fmt.Errorf("Unable to make proxied HEAD request to %v: %v", site, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 && resp.StatusCode != 301 {
		err2 := fmt.Errorf("Proxying to %v via %v returned unexpected status %d,", site, h.ip, resp.StatusCode)
		return false, false, err2
	}

	return true, false, nil
}

func isDuplicateError(err error) bool {
	return strings.Contains(err.Error(), "The record already exists.")
}
