package fronted

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/getlantern/tlsdialer"
)

var (
	poolCh      = make(chan *x509.CertPool, 1)
	candidateCh = make(chan *Masquerade)
	masqCh      = make(chan *Masquerade, 1)
)

func Configure(pool *x509.CertPool, masquerades map[string][]*Masquerade) {
	if masquerades == nil || len(masquerades) == 0 {
		log.Errorf("No masquerades!!")
	}

	go func() {
		poolCh <- pool
		for _, arr := range masquerades {
			shuffle(arr)
			for _, m := range arr {
				candidateCh <- m
			}
		}
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
	d.fillMasquerades()
	return d
}

func (d *direct) fillMasquerades() {
	for i := 0; i < 40; i++ {
		go func() {
			m := <-candidateCh
			log.Debugf("Dialing to %v", m)
			conn, err := d.dialServerWith(m)
			if err != nil {
				log.Debugf("Could not dial to %v, %v", m.IpAddress, err)
			} else {
				log.Debugf("Got successful connection to: %v", m)
				defer func() {
					if err := conn.Close(); err != nil {
						log.Debugf("Could not close body %v", err)
					}
				}()
				masqCh <- m
			}
		}()
	}
}

func (d *direct) getMasquerade() *Masquerade {
	m := <-masqCh

	// Since we know m is already working, simply requeue it.
	go func() {
		masqCh <- m
	}()
	return m
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

// NewHttpClient creates a new http.Client that does direct domain fronting.
func (d *direct) NewDirectHttpClient() *http.Client {
	m := d.getMasquerade()
	trans := &directTransport{}
	trans.Dial = func(network, addr string) (net.Conn, error) {
		log.Debugf("Dialing %s with direct domain fronter", addr)
		conn, err := d.dialServerWith(m)
		if err != nil {
			log.Debugf("Error dialing? %v", err)
		} else {
			log.Debugf("Got connection to %v!", conn.RemoteAddr().String())
		}
		return conn, err
	}
	trans.TLSHandshakeTimeout = 40 * time.Second
	trans.DisableKeepAlives = true
	return &http.Client{
		Transport: trans,
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
