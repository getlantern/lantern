package fronted

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
)

type Direct struct {
	certPool *x509.CertPool
	ms       []*Masquerade
}

// NewDirectDomain creates a new class for doing direct domain fronting using the specified
// set of trusted root CAs.
func NewDirect(certs []string, masquerades []*Masquerade) (*Direct, error) {
	pool, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		log.Debugf("Could not create cert pool: %v", err)
		return nil, err
	}
	return &Direct{certPool: pool, ms: masquerades}, nil
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
	for _, m := range d.ms {
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
		RootCAs:            d.certPool,
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
