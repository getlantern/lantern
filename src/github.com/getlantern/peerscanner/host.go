package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"math/rand"
	"net"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/enproxy"
	"github.com/getlantern/go-dnsimple/dnsimple"
	"github.com/getlantern/peerscanner/cfr"
	"github.com/getlantern/tlsdialer"
	"github.com/getlantern/withtimeout"
)

var (
	// Set a short ttl on DNS entries
	ttl = 30 * time.Second

	// Test with a period of half the ttl
	testPeriod = ttl / 2

	// If we haven't had a successul test or reset after this amount of time,
	// pause testing until receipt of next register call.
	pauseAfter = 10 * time.Minute

	// Limit how long we're willing to wait for status
	statusTimeout = ttl * 2

	dialTimeout    = 3 * time.Second // how long to wait on connecting to host
	requestTimeout = 6 * time.Second // how long to wait for test requests to process
	proxyAttempts  = 1               // how many times to try a test request before considering host down

	// Sites to use for testing connectivity. WARNING - these should only be
	// sites with consistent fast response times, around the world, otherwise
	// tests may time out.
	testSites = []string{"www.google.com", "www.youtube.com", "www.facebook.com"}

	fallbackNamePattern = regexp.MustCompile(`^fl-([a-z]{2})-.+$`)
)

type status struct {
	online            bool
	connectionRefused bool
}

// host is an actor that represents a host entry in CloudFlare and is
// responsible for checking connectivity to the host and updating CloudFlare DNS
// accordingly. Once a host has been created, it sticks around ad infinitum.
// If the host hasn't heard from the real-world host in over 10 minutes, it
// pauses its processing and only resumes once it hears from the client again.
type host struct {
	name        string
	ip          string
	port        string
	cflRecord   *cloudflare.Record
	dspRecord   *dnsimple.Record
	cfrDist     *cfr.Distribution
	isProxying  bool
	cflGroups   map[string]*cflGroup
	dspGroups   map[string]*dspGroup
	lastSuccess time.Time
	lastTest    time.Time

	resetCh      chan string
	unregisterCh chan interface{}
	statusCh     chan chan *status
	initCfrCh    chan interface{}

	proxiedClient     *http.Client
	reportedHost      string
	reportedHostMutex sync.Mutex
}

func (h *host) String() string {
	return fmt.Sprintf("%v (%v)", h.name, h.ip)
}

/*******************************************************************************
 * API for interacting with host
 ******************************************************************************/

// newHost creates a new host for the given name, ip and optional DNS records.
func newHost(name string, ip string, port string, cflRecord *cloudflare.Record, dspRecord *dnsimple.Record) *host {
	h := &host{
		name:         name,
		ip:           ip,
		port:         port,
		cflRecord:    cflRecord,
		dspRecord:    dspRecord,
		resetCh:      make(chan string, 1000),
		unregisterCh: make(chan interface{}, 1),
		statusCh:     make(chan chan *status, 1000),
		initCfrCh:    make(chan interface{}, 1),
	}

	if h.isFallback() {

		h.cflGroups = map[string]*cflGroup{
			RoundRobin: &cflGroup{subdomain: RoundRobin},
			Fallbacks:  &cflGroup{subdomain: Fallbacks},
			Peers:      &cflGroup{subdomain: Peers},
		}
		h.dspGroups = map[string]*dspGroup{
			RoundRobin: &dspGroup{subdomain: RoundRobin},
			Fallbacks:  &dspGroup{subdomain: Fallbacks},
			Peers:      &dspGroup{subdomain: Peers},
		}
		country := fallbackCountry(name)
		if country != "" {
			// Add host to country-specific rotation
			h.cflGroups[country] = &cflGroup{subdomain: country}
			h.dspGroups[country] = &dspGroup{subdomain: country}
		}
	} else {
		log.Errorf("Somehow adding peer host? %v (%v)", name, ip)
	}

	return h
}

// resetProxiedClient reconfigures the host so attempts to proxy through it,
// for the sake of checking whether it's up and serving, will use the given
// port.  Valid port values are "443", in which case we'll access the proxy
// through HTTPS, or "80", for an unencrypted connection.
//
// This is necessary because when peerscanner starts up and gets the list of
// hosts from the various DNS/CDN services, it has no way to know what port
// these servers are listening at.  So we want to try both until one works, or
// until the server first registers with peerscanner, advertising which port
// it uses.
func (h *host) resetProxiedClient(port string) {

	var dial func(addr string) (net.Conn, error)
	if port == "80" {
		dial = func(addr string) (net.Conn, error) {
			dialer := net.Dialer{Timeout: dialTimeout}
			return dialer.Dial("tcp", h.ip+":80")
		}
	} else if port == "443" {
		dial = func(addr string) (net.Conn, error) {
			return tlsdialer.DialWithDialer(&net.Dialer{
				Timeout: dialTimeout,
			}, "tcp", h.ip+":443", true, &tls.Config{
				InsecureSkipVerify: true,
				// Cache TLS sessions
				ClientSessionCache: tls.NewLRUClientSessionCache(1000),
			})
		}
	} else {
		log.Errorf("Unsupported port: %v", port)
		return
	}

	h.proxiedClient = &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return enproxy.Dial(addr, &enproxy.Config{
					DialProxy: dial,
					NewRequest: func(upstreamHost string, method string, body io.Reader) (req *http.Request, err error) {
						return http.NewRequest(method, "http://"+h.ip+"/", body)
					},
					OnFirstResponse: func(resp *http.Response) {
						h.reportedHostMutex.Lock()
						h.reportedHost = resp.Header.Get(enproxy.X_ENPROXY_PROXY_HOST)
						h.reportedHostMutex.Unlock()
					},
				})
			},
			DisableKeepAlives: true,
		},
		Timeout: requestTimeout,
	}
}

// status returns the status of this host as of the next scheduled check
func (h *host) status() (online bool, connectionRefused bool, timedOut bool) {
	// Buffer the channel so that if we time out, reportStatus can still report
	// without blocking.
	sch := make(chan *status, 1)
	h.statusCh <- sch
	select {
	case s := <-sch:
		return s.online, s.connectionRefused, false
	case <-time.After(statusTimeout):
		return false, false, true
	}
}

// reset resets this host's run loop in response to the host having reported in,
// which can include changing the name if the given name is new.
func (h *host) reset(newName string) {
	h.resetCh <- newName
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

func (h *host) initCloudfront() {
	h.initCfrCh <- nil
}

func (h *host) doInitCfrDist() {
	if h.cfrDist != nil && h.cfrDist.Status == "InProgress" {
		cfr.RefreshStatus(cfrutil, h.cfrDist)
	}
	if h.cfrDist == nil {
		dist, err := cfr.CreateDistribution(
			cfrutil,
			h.name,
			h.name+"."+*dspdomain,
			"created by peerscanner",
		)
		if err == nil {
			h.cfrDist = dist
		} else {
			log.Debugf("Error trying to initialize cloudfront distribution for %v: %v", h.name, err)
		}
	}
}

/*******************************************************************************
 * Implementation
 ******************************************************************************/

// run is the main run loop for this host
func (h *host) run() {
	checkImmediately := true
	h.lastSuccess = time.Now()
	h.lastTest = time.Now()
	periodTimer := time.NewTimer(0)
	pauseTimer := time.NewTimer(0)

	for {
		if !checkImmediately {
			// Limit the rate at which we run tests
			waitTime := h.lastTest.Add(testPeriod).Sub(time.Now())
			log.Tracef("Waiting %v until testing %v", waitTime, h)
			periodTimer.Reset(waitTime)
		}

		// Pause run loop after some largish amount of time
		pauseTimer.Reset(h.lastSuccess.Add(pauseAfter).Sub(time.Now()))

		select {
		case newName := <-h.resetCh:
			h.doReset(newName)
		case <-h.unregisterCh:
			log.Debugf("Unregistering %v and pausing", h)
			h.pause()
			checkImmediately = true
		case <-h.initCfrCh:
			h.doInitCfrDist()
		case <-pauseTimer.C:
			log.Debugf("%v had no successful checks or resets in %v, pausing", h, pauseAfter)
			h.pause()
			checkImmediately = true
		case <-periodTimer.C:
			log.Tracef("Testing %v", h)
			_s, timedOut, err := withtimeout.Do(ttl, func() (interface{}, error) {
				online, connectionRefused, err := h.isAbleToProxy()
				return &status{online, connectionRefused}, err
			})
			s := &status{false, false}
			if timedOut {
				log.Debugf("Testing %v timed out unexpectedly", h)
			}
			if _s != nil {
				s = _s.(*status)
			}
			h.reportStatus(s)
			h.lastTest = time.Now()
			checkImmediately = false
			if s.online {
				log.Tracef("Test for %v successful", h)
				h.lastSuccess = time.Now()
				err := h.register()
				if err != nil {
					log.Errorf("Error registering %v: %v", h, err)
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

// pause deregisters this host from rotations and then waits for the next reset
// before continuing
func (h *host) pause() {
	h.deregisterFromRotations()
	log.Debugf("%v paused", h)
	for {
		select {
		case newName := <-h.resetCh:
			log.Debugf("Unpausing checks for %v", h)
			h.doReset(newName)
			return
		case <-h.unregisterCh:
			log.Tracef("Ignoring unregister while paused")
		}
	}
}

// reportStatus reports the given status back to any callers that are waiting
// for it.
func (h *host) reportStatus(s *status) {
	for {
		select {
		case sch := <-h.statusCh:
			sch <- s
		default:
			return
		}
	}
}

func (h *host) doReset(newName string) {
	log.Tracef("Host notified us of its presence")
	if newName != h.name {
		log.Debugf("Hostname for %v changed to %v", h, newName)
		var cflErr, dspErr error
		if h.cflRecord != nil {
			log.Debugf("Deregistering old Cloudflare hostname %v", h.name)
			cflErr = h.doDeregisterCflHost()
			if cflErr != nil {
				log.Error(cflErr.Error())
			}
		}
		if h.dspRecord != nil {
			log.Debugf("Deregistering old DNSimple hostname %v", h.name)
			dspErr = h.doDeregisterDspHost()
			if dspErr != nil {
				log.Error(dspErr.Error())
			}
		}
		if cflErr != nil || dspErr != nil {
			return
		}
		h.name = newName
	}
	h.lastSuccess = time.Now()
	h.lastTest = time.Time{}
}

/*******************************************************************************
 * Functions for managing DNS
 ******************************************************************************/

func (h *host) register() error {
	cflErr := h.registerCfl()
	dspErr := h.registerDsp()
	if cflErr != nil && dspErr == nil {
		return fmt.Errorf("Error registering Cloudflare: %v", cflErr)
	} else if cflErr == nil && dspErr != nil {
		return fmt.Errorf("Error registering DNSSimple: %v", dspErr)
	} else if cflErr != nil && dspErr != nil {
		return fmt.Errorf("Error registering (CFL: %v) (DNSSimple: %v)", cflErr, dspErr)
	}
	return nil
}

func (h *host) registerCfl() error {
	err := h.registerCflHost()
	if err != nil {
		return fmt.Errorf("Unable to register Cloudflare host %v: %v", h, err)
	}
	err = h.registerToCflRotations()
	if err != nil {
		return err
	}
	return nil
}

func (h *host) registerDsp() error {
	err := h.registerDspHost()
	if err != nil {
		return fmt.Errorf("Unable to register DNSimple host %v: %v", h, err)
	}
	err = h.registerToDspRotations()
	if err != nil {
		return err
	}
	return nil
}

func (h *host) registerCflHost() error {
	if h.isProxying {
		log.Debugf("Cloudflare record already registered, no need to re-register: %v", h)
		return nil
	}
	log.Debugf("Registering Cloudflare record %v", h)
	var err error
	h.cflRecord, h.isProxying, err = cflutil.EnsureRegistered(h.name, h.ip, h.cflRecord)
	return err
}

func (h *host) registerDspHost() error {
	if h.dspRecord != nil {
		log.Debugf("DNSimple record already registered, no need to re-register: %v", h)
		return nil
	}
	log.Debugf("Registering DNSimple %v", h)
	var err error
	h.dspRecord, err = dsputil.Register(h.name, h.ip)
	return err
}

func (h *host) registerToCflRotations() error {
	for _, group := range h.cflGroups {
		err := group.register(h)
		if err != nil {
			return err
		}
	}
	return nil
}

func (h *host) registerToDspRotations() error {
	if !h.cfrDistReady() {
		log.Debugf("Cloudfront distribution for %v not ready yet; not registering to rotations.", h.name)
		return nil
	}
	for _, group := range h.dspGroups {
		err := group.register(h)
		if err != nil {
			return err
		}
	}
	return nil
}

func (h *host) deregisterFromRotations() {
	for _, group := range h.cflGroups {
		group.deregister(h)
	}
	for _, group := range h.dspGroups {
		group.deregister(h)
	}
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
			log.Tracef("Error testing %v: %v", h, err.Error())
		}
		lastErr = err
		if success || connectionRefused {
			// If we've succeeded, or our connection was flat-out refused, don't
			// bother trying to proxy again

			if success {
				// Make sure that the server is reporting the correct host name for sticky
				// routing.
				h.reportedHostMutex.Lock()
				defer h.reportedHostMutex.Unlock()
				if !h.reportedHostOk() {
					success = false
					lastErr := fmt.Errorf("%v is reporting an unexpected host %v", h, h.reportedHost)
					log.Error(lastErr.Error())
				}
			}

			return success, connectionRefused, lastErr
		}
	}
	return false, false, lastErr
}

func (h *host) doIsAbleToProxy() (bool, bool, error) {
	if h.port == "" {
		h.resetProxiedClient("80")
		success, connectionRefused, err := h.reallyDoIsAbleToProxy("80")
		if success {
			h.port = "80"
			return success, connectionRefused, err
		}
		h.resetProxiedClient("443")
		success, connectionRefused, err = h.reallyDoIsAbleToProxy("443")
		if success {
			h.port = "443"
		}
		return success, connectionRefused, err
	} else if h.proxiedClient == nil {
		h.resetProxiedClient(h.port)
	}
	return h.reallyDoIsAbleToProxy(h.port)
}

func (h *host) reallyDoIsAbleToProxy(port string) (bool, bool, error) {
	// First just try a plain TCP connection. This is useful because the
	// underlying TCP-level error is consumed in the flashlight layer, and we
	// need that to be accessible on the client side in the logic for deciding
	// whether or not to display the port mapping message.
	//XXX: allow port 80 too
	addr := h.ip + ":" + port
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

// fallbackCountry returns the country code of a fallback if it follows the
// usual naming convention.
func fallbackCountry(name string) string {
	sub := fallbackNamePattern.FindSubmatch([]byte(name))
	if len(sub) == 2 {
		return string(sub[1]) + ".fallbacks"
	}
	return ""
}

func (h *host) doDeregisterCflHost() error {
	err := cflutil.DestroyRecord(h.cflRecord)
	h.cflRecord = nil
	h.isProxying = false
	if err != nil {
		return fmt.Errorf("Unable to deregister Cloudflare record %v: %v", h, err)
	}
	return nil
}

func (h *host) doDeregisterDspHost() error {
	err := dsputil.DestroyRecord(h.dspRecord)
	h.dspRecord = nil
	if err != nil {
		return fmt.Errorf("Unable to deregister DNSimple record %v: %v", h, err)
	}
	return nil
}

func (h *host) cfrDistReady() bool {
	return h.cfrDist != nil && h.cfrDist.Status == "Deployed"
}

func (h *host) reportedHostOk() bool {
	// Match the FQDN at Cloudflare or Cloudfront
	return (h.reportedHost == h.name+"."+*cfldomain) || (h.cfrDistReady() && h.reportedHost == h.cfrDist.Domain)
}
