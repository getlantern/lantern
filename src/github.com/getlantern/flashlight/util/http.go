package util

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"net/url"

	"github.com/getlantern/keyman"
)

// HTTPClient creates an http.Client. If rootCA is specified, the client will
// validate the server's certificate on TLS connections against that RootCA. If
// proxyAddr is specified, the client will proxy through the given http proxy.
func HTTPClient(rootCA string, proxyAddr string) (*http.Client, error) {
	tr := &http.Transport{}
	if rootCA != "" {
		caCert, err := keyman.LoadCertificateFromPEMBytes([]byte(rootCA))
		if err != nil {
			return nil, fmt.Errorf("Unable to decode rootCA: %s", err)
		}
		tr.TLSClientConfig = &tls.Config{
			RootCAs: caCert.PoolContainingCert(),
		}
	}
	if proxyAddr != "" {
		tr.Proxy = func(req *http.Request) (*url.URL, error) {
			host, _, err := net.SplitHostPort(proxyAddr)
			if err != nil {
				return nil, fmt.Errorf("Unable to split host and port for %v: %v", proxyAddr, err)
			}
			noHostSpecified := host == ""
			if noHostSpecified {
				// For addresses of the form ":8080", prepend the loopback IP
				proxyAddr = "127.0.0.1" + proxyAddr
			}
			return url.Parse("http://" + proxyAddr)
		}
	}
	return &http.Client{Transport: tr}, nil
}
