package util

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
	"github.com/getlantern/waitforserver"
)

var (
	log = golog.LoggerFor("flashlight.util")
)

// PersistentHTTPClient creates an http.Client that persists across requests.
// If rootCA is specified, the client will validate the server's certificate
// on TLS connections against that RootCA. If proxyAddr is specified, the client
// will proxy through the given http proxy.
func PersistentHTTPClient(rootCA string, proxyAddr string) (*http.Client, error) {
	return httpClient(rootCA, proxyAddr, true)
}

// HTTPClient creates an http.Client. If rootCA is specified, the client will
// validate the server's certificate on TLS connections against that RootCA. If
// proxyAddr is specified, the client will proxy through the given http proxy.
func HTTPClient(rootCA string, proxyAddr string) (*http.Client, error) {
	return httpClient(rootCA, proxyAddr, false)
}

// httpClient creates an http.Client. If rootCA is specified, the client will
// validate the server's certificate on TLS connections against that RootCA. If
// proxyAddr is specified, the client will proxy through the given http proxy.
func httpClient(rootCA string, proxyAddr string, persistent bool) (*http.Client, error) {

	log.Debugf("Creating new HTTPClient with proxy: %v", proxyAddr)

	tr := &http.Transport{
		Dial: (&net.Dialer{
			Timeout:   60 * time.Second,
			KeepAlive: 30 * time.Second,
		}).Dial,
		TLSHandshakeTimeout: 10 * time.Second,

		// This method is typically used for creating a one-off HTTP client
		// that we don't want to keep around for future calls, making
		// persistent connections a potential source of file descriptor
		// leaks. Note the name of this variable is misleading -- it would
		// be clearer to call it DisablePersistentConnections -- i.e. it has
		// nothing to do with TCP keep alives along the lines of the KeepAlive
		// variable in net.Dialer.
		DisableKeepAlives: !persistent,
	}

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

		host, _, err := net.SplitHostPort(proxyAddr)
		if err != nil {
			return nil, fmt.Errorf("Unable to split host and port for %v: %v", proxyAddr, err)
		}

		noHostSpecified := host == ""
		if noHostSpecified {
			// For addresses of the form ":8080", prepend the loopback IP
			host = "127.0.0.1"
			proxyAddr = host + proxyAddr
		}

		if isLoopback(host) {
			log.Debugf("Waiting for loopback proxy server to came online...")
			// Waiting for proxy server to came online.
			err := waitforserver.WaitForServer("tcp", proxyAddr, 60*time.Second)
			if err != nil {
				// Instead of finishing here we just log the error and continue, the client
				// we are going to create will surely fail when used and return errors,
				// those errors should be handled by the code that depends on such client.
				log.Errorf("Proxy never came online at %v: %q", proxyAddr, err)
			}
			log.Debugf("Connected to proxy on localhost")
		} else {
			log.Errorf("Attempting to proxy through server other than loopback %v", host)
		}

		tr.Proxy = func(req *http.Request) (*url.URL, error) {
			return url.Parse("http://" + proxyAddr)
		}
	} else {
		log.Errorf("Using direct http client with no proxyAddr")
	}
	return &http.Client{Transport: tr}, nil
}

func isLoopback(host string) bool {
	if host == "localhost" {
		return true
	}
	var ip net.IP
	if ip = net.ParseIP(host); ip != nil {
		return ip.IsLoopback()
	}
	return false
}
