package fronted

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/getlantern/tlsdialer"
)

var (
	poolCh        = make(chan *x509.CertPool, 1)
	masqueradesCh = make(chan []*Masquerade, 1)
)

func Configure(pool *x509.CertPool, masquerades map[string][]*Masquerade) {
	poolCh <- pool

	m := make([]*Masquerade, 0, len(masquerades))

	for _, value := range masquerades {
		for _, masq := range value {
			m = append(m, masq)
		}
	}

	masqueradesCh <- m
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

type Direct struct {
}

// DirectTransport is a wrapper struct enabling us to modify the protocol of outgoing
// requests to make them all HTTP instead of potentially HTTPS, which breaks our particular
// implemenation of direct domain fronting.
type DirectTransport struct {
	http.Transport
}

func (ddf *DirectTransport) RoundTrip(req *http.Request) (resp *http.Response, err error) {
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

// Response returns the raw response body from the first masquerade that provides a
// successful response.
func (d *Direct) Response(url string) (*http.Response, error) {
	for _, m := range getMasquerades() {
		client := d.NewHttpClient(m)
		if resp, err := client.Get(url); err != nil {
			continue
		} else {
			return resp, nil
		}
	}
	msg := fmt.Sprintf("Could not get response from any masquerade!")

	log.Error(msg)
	return nil, fmt.Errorf(msg)
}

// NewHttpClient creates a new http.Client that does direct domain fronting.
func (d *Direct) NewHttpClient(m *Masquerade) *http.Client {
	log.Debugf("Creating new direct domain fronter.")
	tlsConfig := &tls.Config{
		// TODO: Should we cache this globally accross http clients?
		ClientSessionCache: tls.NewLRUClientSessionCache(1000),
		InsecureSkipVerify: false,
		ServerName:         m.Domain,
		RootCAs:            getCertPool(),
	}
	trans := &DirectDomainTransport{}
	trans.Dial = func(network, addr string) (net.Conn, error) {
		log.Debugf("Dialing %s with direct domain fronter", addr)
		return dialServerWith(m, tlsConfig)
	}
	trans.TLSHandshakeTimeout = 40 * time.Second
	trans.DisableKeepAlives = true
	return &http.Client{
		Transport: trans,
	}
}

func dialServerWith(masquerade *Masquerade, tlsConfig *tls.Config) (net.Conn, error) {
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
