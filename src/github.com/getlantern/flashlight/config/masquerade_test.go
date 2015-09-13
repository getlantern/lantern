package config

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"testing"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
)

// DirectDomainTransport is a wrapper struct enabling us to modify the protocol of outgoing
// requests to make them all HTTP instead of potentially HTTPS, which breaks our particular
// implemenation of direct domain fronting.
type DirectDomainTransport struct {
	http.Transport
}

func (ddf *DirectDomainTransport) RoundTrip(req *http.Request) (resp *http.Response, err error) {
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

// Creates a new http.Client that does direct domain fronting.
func NewHttpClient(m *fronted.Masquerade, tlsConfig *tls.Config) *http.Client {
	log.Debugf("Creating new direct domain fronter.")
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
func TestMasquerade(t *testing.T) {
	certPool, err := trustedCACerts()
	if err != nil {
		t.Fail()
	}

	m := cloudfrontMasquerades[0]
	tlsConfig := &tls.Config{
		ClientSessionCache: tls.NewLRUClientSessionCache(1000),
		InsecureSkipVerify: false,
		ServerName:         m.Domain,
		RootCAs:            certPool,
	}
	client := NewHttpClient(m, tlsConfig)

	if resp, err := client.Get("https://d2wi0vwulmtn99.cloudfront.net/cloud.yaml.gz"); err != nil {
		log.Errorf("Could not get response: %v", err)
	} else {
		if body, err := httputil.DumpResponse(resp, false); err != nil {
			log.Errorf("Could not dump response: %v", err)
		} else {
			log.Debugf("Response: \n%v", string(body))
		}
	}
	log.Debugf("End test\n\n\n\n")
}

func dialServerWith(masquerade *fronted.Masquerade, tlsConfig *tls.Config) (net.Conn, error) {
	log.Debugf("DIALING SERVER: %v", masquerade.Domain)
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

func trustedCACerts() (*x509.CertPool, error) {
	certs := make([]string, 0, len(defaultTrustedCAs))
	for _, ca := range defaultTrustedCAs {
		certs = append(certs, ca.Cert)
	}
	return keyman.PoolContainingCerts(certs...)
}
