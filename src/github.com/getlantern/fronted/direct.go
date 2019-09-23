package fronted

import (
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
	"github.com/getlantern/idletiming"
	"github.com/getlantern/tlsdialer"
)

const (
	NumberToVetInitially = 20
)

var (
	log       = golog.LoggerFor("fronted")
	_instance = eventual.NewValue()
)

type direct struct {
	tlsConfigsMutex sync.Mutex
	tlsConfigs      map[string]*tls.Config
	certPool        *x509.CertPool
	candidates      chan *Masquerade
	masquerades     chan *Masquerade
}

func Configure(pool *x509.CertPool, masquerades map[string][]*Masquerade) {
	log.Debug("Configuring fronted")
	if masquerades == nil || len(masquerades) == 0 {
		log.Errorf("No masquerades!!")
		return
	}

	// Make a copy of the masquerades to avoid data races.
	size := 0
	for _, v := range masquerades {
		size += len(v)
	}

	if size == 0 {
		log.Errorf("No masquerades!!")
		return
	}

	instance := &direct{
		tlsConfigs:  make(map[string]*tls.Config),
		certPool:    pool,
		candidates:  make(chan *Masquerade, size),
		masquerades: make(chan *Masquerade, size),
	}

	_instance.Set(instance)
	instance.loadCandidates(masquerades)
	instance.vetInitial()
}

func (d *direct) loadCandidates(initial map[string][]*Masquerade) {
	log.Debug("Loading candidates")
	for key, arr := range initial {
		size := len(arr)
		log.Tracef("Adding %d candidates for %v", size, key)
		for i := 0; i < size; i++ {
			// choose index uniformly in [i, n-1]
			r := i + rand.Intn(size-i)
			log.Trace("Adding candidate")
			d.candidates <- arr[r]
		}
	}
}

func (d *direct) vetInitial() {
	log.Debugf("Vetting %d initial candidates in parallel", NumberToVetInitially)
	for i := 0; i < NumberToVetInitially; i++ {
		go d.vetOne()
	}
}

func (d *direct) vetOne() {
	// We're just testing the ability to connect here, destination site doesn't
	// really matter
	for {
		log.Trace("Vetting one")
		conn, masqueradesRemain, err := d.dialWith(d.candidates, "tcp", "www.google.com")
		if err == nil {
			conn.Close()
			log.Trace("Finished vetting one")
			return
		}
		if !masqueradesRemain {
			log.Trace("Nothing left to vet")
			return
		}
	}
}

func NewDirectHttpClient(timeout time.Duration) *http.Client {
	instance, ok := _instance.Get(timeout)
	if !ok {
		panic(fmt.Errorf("No DirectHttpClient available within %v", timeout))
	}
	return instance.(*direct).NewDirectHttpClient()
}

// NewDirectHttpClient creates a new http.Client that does direct domain fronting.
func (d *direct) NewDirectHttpClient() *http.Client {
	trans := &directTransport{}
	trans.Dial = d.Dial
	trans.TLSHandshakeTimeout = 40 * time.Second
	trans.DisableKeepAlives = true
	return &http.Client{
		Transport: trans,
	}
}

// Do continually retries a given request until it succeeds because some fronting providers
// will return a 403 for some domains.
func (d *direct) Do(req *http.Request) (*http.Response, error) {
	for i := 0; i < 6; i++ {
		client := d.NewDirectHttpClient()
		if resp, err := client.Do(req); err != nil {
			log.Errorf("Could not complete request %v", err)
		} else if resp.StatusCode > 199 && resp.StatusCode < 400 {
			return resp, err
		} else {
			_ = resp.Body.Close()
		}
	}
	return nil, errors.New("Could not complete request even with retries")
}

// Dial dials the given address using a masquerade. If the available masquerade
// fails, it retries with others until it either succeeds or exhausts the
// available masquerades.
func (d *direct) Dial(network, addr string) (net.Conn, error) {
	conn, _, err := d.dialWith(d.masquerades, network, addr)
	return conn, err
}

func (d *direct) dialWith(in chan *Masquerade, network, addr string) (net.Conn, bool, error) {
	retryLater := make([]*Masquerade, 0)
	defer func() {
		for _, m := range retryLater {
			in <- m
		}
	}()

	for {
		var m *Masquerade
		select {
		case m = <-in:
			log.Trace("Got vetted masquerade")
		default:
			log.Trace("No vetted masquerade found, falling back to unvetted candidate")
			select {
			case m = <-d.candidates:
				log.Trace("Got unvetted masquerade")
			default:
				return nil, false, errors.New("Could not dial any masquerade?")
			}
		}

		log.Debugf("Dialing to %v", m)

		// We do the full TLS connection here because in practice the domains at a given IP
		// address can change frequently on CDNs, so the certificate may not match what
		// we expect.
		if conn, err := d.dialServerWith(m); err != nil {
			log.Debugf("Could not dial to %v, %v", m.IpAddress, err)
			// Don't re-add this candidate if it's any certificate error, as that
			// will just keep failing and will waste connections. We can't access the underlying
			// error at this point so just look for "certificate" and "handshake".
			if strings.Contains(err.Error(), "certificate") || strings.Contains(err.Error(), "handshake") {
				log.Debugf("Not re-adding candidate that failed on error '%v'", err.Error())
			} else {
				log.Debugf("Unexpected error dialing, keeping masquerade: %v", err)
				retryLater = append(retryLater, m)
			}
		} else {
			log.Debugf("Got successful connection to: %v", m)
			if err := d.headCheck(m); err != nil {
				log.Debugf("Could not perform successful head request: %v", err)
			} else {
				// Requeue the working connection to masquerades
				d.masquerades <- m
				idleTimeout := 70 * time.Second

				log.Debug("Wrapping connecting in idletiming connection")
				conn = idletiming.Conn(conn, idleTimeout, func() {
					log.Debugf("Connection to %s via %s idle for %v, closing", addr, conn.RemoteAddr(), idleTimeout)
					if err := conn.Close(); err != nil {
						log.Debugf("Unable to close connection: %v", err)
					}
				})
				log.Debug("Returning connection")
				return conn, true, nil
			}
		}
	}
}

func (d *direct) dialServerWith(masquerade *Masquerade) (net.Conn, error) {
	tlsConfig := d.tlsConfig(masquerade)
	dialTimeout := 10 * time.Second
	sendServerNameExtension := false

	cwt, err := tlsdialer.DialForTimings(
		&net.Dialer{
			Timeout: dialTimeout,
		},
		"tcp",
		masquerade.IpAddress+":443",
		sendServerNameExtension, // SNI or no
		tlsConfig)

	if err != nil && masquerade != nil {
		err = fmt.Errorf("Unable to dial masquerade %s: %s", masquerade.Domain, err)
	}
	return cwt.Conn, err
}

// tlsConfig builds a tls.Config for dialing the upstream host. Constructed
// tls.Configs are cached on a per-masquerade basis to enable client session
// caching and reduce the amount of PEM certificate parsing.
func (d *direct) tlsConfig(m *Masquerade) *tls.Config {
	d.tlsConfigsMutex.Lock()
	defer d.tlsConfigsMutex.Unlock()

	tlsConfig := d.tlsConfigs[m.Domain]
	if tlsConfig == nil {
		tlsConfig = &tls.Config{
			ClientSessionCache: tls.NewLRUClientSessionCache(1000),
			InsecureSkipVerify: false,
			ServerName:         m.Domain,
			RootCAs:            d.certPool,
		}
		d.tlsConfigs[m.Domain] = tlsConfig
	}

	return tlsConfig
}

// headCheck checks to make sure we can actually make a DDF head request through a
// given masquerade. We don't reuse the underlying connection here because that confuses
// the http.Client's internal transport.
func (d *direct) headCheck(m *Masquerade) error {
	trans := &http.Transport{
		Dial: func(network, address string) (net.Conn, error) {
			return d.dialServerWith(m)
		},
		TLSHandshakeTimeout: 40 * time.Second,
		DisableKeepAlives:   true,
	}

	client := &http.Client{
		Transport: trans,
	}
	url := "http://dlymairwlc89h.cloudfront.net/index.html"
	if resp, err := client.Head(url); err != nil {
		return err
	} else {
		defer resp.Body.Close()
		if 200 != resp.StatusCode {
			return fmt.Errorf("Unexpected response status: %v, %v", resp.StatusCode, resp.Status)
		}
	}
	log.Debugf("Successfully passed HEAD request through: %v", m)
	return nil
}

// directTransport is a wrapper struct enabling us to modify the protocol of outgoing
// requests to make them all HTTP instead of potentially HTTPS, which breaks our particular
// implemenation of direct domain fronting.
type directTransport struct {
	http.Transport
}

func (ddf *directTransport) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	// The connection is already encrypted by domain fronting.  We need to rewrite URLs starting
	// with "https://" to "http://", lest we get an error for doubling up on TLS.

	// The RoundTrip interface requires that we not modify the memory in the request, so we just
	// create a copy.
	norm := new(http.Request)
	*norm = *req // includes shallow copies of maps, but okay
	norm.URL = new(url.URL)
	*norm.URL = *req.URL
	norm.URL.Scheme = "http"
	return ddf.Transport.RoundTrip(norm)
}
