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

	"github.com/getlantern/idletiming"
	"github.com/getlantern/tlsdialer"
)

var (
	poolCh      = make(chan *x509.CertPool, 1)
	candidateCh = make(chan *Masquerade, 1)
	masqCh      = make(chan *Masquerade, 1)
)

func Configure(pool *x509.CertPool, masquerades map[string][]*Masquerade) {
	if masquerades == nil || len(masquerades) == 0 {
		log.Errorf("No masquerades!!")
	}

	// Make a copy of the masquerades to avoid data races.
	masq := make(map[string][]*Masquerade)
	for k, v := range masquerades {
		c := make([]*Masquerade, len(v))
		copy(c, v)
		masq[k] = c
	}
	size := 0
	for _, arr := range masq {
		shuffle(arr)
		size += len(arr)
	}

	// Make an unblocked channel the same size as our group
	// of masquerades and push all of them into it.
	candidateCh = make(chan *Masquerade, size)

	go func() {
		log.Debugf("Adding %v candidates...", size)
		for _, arr := range masq {
			for _, m := range arr {
				candidateCh <- m
			}
		}
		poolCh <- pool
	}()
}

func shuffle(slc []*Masquerade) {
	n := len(slc)
	for i := 0; i < n; i++ {
		// choose index uniformly in [i, n-1]
		r := i + rand.Intn(n-i)
		slc[r], slc[i] = slc[i], slc[r]
	}
}

func getCertPool() *x509.CertPool {
	pool := <-poolCh
	if len(poolCh) == 0 {
		poolCh <- pool
	}
	return pool
}

type direct struct {
	tlsConfigs      map[string]*tls.Config
	tlsConfigsMutex sync.Mutex
}

func NewDirect() *direct {
	d := &direct{
		tlsConfigs: make(map[string]*tls.Config),
	}
	return d
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

// Dial persistently dials masquerades until one succeeds.
func (d *direct) Dial(network, addr string) (net.Conn, error) {
	gotFirst := false
	for {
		select {
		case m := <-candidateCh:
			gotFirst = true
			log.Debugf("Dialing to %v", m)

			// We do the full TLS connection here because in practice the domains at a given IP
			// address can change frequently on CDNs, so the certificate may not match what
			// we expect.
			conn, err := d.dialServerWith(m)
			if err != nil {
				log.Debugf("Could not dial to %v, %v", m.IpAddress, err)
				// Don't re-add this candidate if it's any certificate error, as that
				// will just keep failing and will waste connections. We can't access the underlying
				// error at this point so just look for "certificate".
				if strings.Contains(err.Error(), "certificate") {
					log.Debugf("Continuing on certificate error")
				} else {
					candidateCh <- m
				}
			} else {
				log.Debugf("Got successful connection to: %v", m)
				// Requeue the working connection
				candidateCh <- m
				idleTimeout := 70 * time.Second

				log.Debug("Wrapping connecting in idletiming connection")
				conn = idletiming.Conn(conn, idleTimeout, func() {
					log.Debugf("Connection to %s via %s idle for %v, closing", addr, conn.RemoteAddr(), idleTimeout)
					if err := conn.Close(); err != nil {
						log.Debugf("Unable to close connection: %v", err)
					}
				})
				log.Debug("Returning connection")
				return conn, nil
			}
		default:
			if gotFirst {
				return nil, errors.New("Could not dial any masquerade?")
			}
		}
	}
}

func (d *direct) dialServerWith(masquerade *Masquerade) (net.Conn, error) {
	tlsConfig := d.tlsConfig(masquerade)
	dialTimeout := 30 * time.Second
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
			RootCAs:            getCertPool(),
		}
		d.tlsConfigs[m.Domain] = tlsConfig
	}

	return tlsConfig
}
