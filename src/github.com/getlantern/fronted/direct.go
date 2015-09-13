package fronted

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
)

type Direct struct {
	certPool *x509.CertPool
}

// NewDirectDomain creates a new class for doing direct domain fronting using the specified
// set of trusted root CAs.
func NewDirectDomain(certs []string) (*Direct, error) {
	pool, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		log.Debugf("Could not create cert pool: %v", err)
		return nil, err
	}
	return &Direct{pool}, nil
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
func (d *Direct) Response(url string, ms []*Masquerade) ([]byte, error) {
	for _, m := range ms {
		client := d.NewHttpClient(m)

		if resp, err := client.Get(url); err != nil {
			continue
		} else {
			defer resp.Body.Close()
			if 200 != resp.StatusCode {
				log.Errorf("Unexpected status code %v for domain %v", resp.StatusCode, m.Domain)
				continue
			}
			if body, err := ioutil.ReadAll(resp.Body); err != nil {
				log.Errorf("Unexpected error %v for domain %v", err, m.Domain)
				continue
			} else {
				return body, nil
			}
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
	return &http.Client{
		Transport: &DirectDomainTransport{
			Transport: http.Transport{
				Dial: func(network, addr string) (net.Conn, error) {
					log.Debugf("Dialing %s with direct domain fronter", addr)
					return dialServerWith(m, tlsConfig)
				},
				TLSHandshakeTimeout: 40 * time.Second,
				DisableKeepAlives:   true,
			},
		},
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
