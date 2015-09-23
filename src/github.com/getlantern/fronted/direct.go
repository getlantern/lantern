package fronted

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/getlantern/tlsdialer"
)

var (
	poolCh        = make(chan *x509.CertPool, 1)
	masqueradesCh = make(chan []*Masquerade, 1)
	masqCh        = make(chan *Masquerade, 1)
)

func Configure(pool *x509.CertPool, masquerades []*Masquerade) {
	poolCh <- pool
	masqueradesCh <- masquerades
}

func getCertPool() *x509.CertPool {
	pool := <-poolCh
	if len(poolCh) == 0 {
		poolCh <- pool
	}
	return pool
}

func getMasquerades() []*Masquerade {
	m := <-masqueradesCh
	if len(masqueradesCh) == 0 {
		masqueradesCh <- m
	}
	return m
}

func getMasquerade() *Masquerade {
	if len(masqCh) > 0 {
		return <-masqCh
	}
	log.Debugf("Refreshing live masquerades")
	ms := <-masqueradesCh
	size := len(ms)
	for i := 0; i < 10; i++ {
		go func() {
			r := rand.Intn(size)
			m := ms[r]
			if strings.Contains(m.Domain, "cloudfront") {
				return
			}
			log.Debugf("Dialing to %v", m)
			conn, err := dialServerWith(m)
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
	return <-masqCh
}

type Direct struct {
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
func NewDirectHttpClient() *http.Client {
	log.Debugf("Creating new direct domain fronter")
	m := getMasquerade()
	log.Debugf("Using %v", m)
	trans := &directTransport{}
	trans.Dial = func(network, addr string) (net.Conn, error) {
		log.Debugf("Dialing %s with direct domain fronter", addr)
		conn, err := dialServerWith(m)
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

func dialServerWith(masquerade *Masquerade) (net.Conn, error) {
	tlsConfig := &tls.Config{
		// TODO: Should we cache this globally accross http clients?
		ClientSessionCache: tls.NewLRUClientSessionCache(1000),
		InsecureSkipVerify: false,
		ServerName:         masquerade.Domain,
		RootCAs:            getCertPool(),
	}
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
