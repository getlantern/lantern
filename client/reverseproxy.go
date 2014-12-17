package client

import (
	"net/http"
	"net/http/httputil"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/flashlight/proxy"
)

func (client *Client) getReverseProxy() *httputil.ReverseProxy {
	rp := <-client.rpCh
	client.rpCh <- rp
	return rp
}

func (client *Client) initReverseProxy(bal *balancer.Balancer, dumpHeaders bool) {
	rp := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			// do nothing
		},
		Transport: withDumpHeaders(
			dumpHeaders,
			&http.Transport{
				// We disable keepalives because some servers pretend to support
				// keep-alives but close their connections immediately, which
				// causes an error inside ReverseProxy.  This is not an issue
				// for HTTPS because  the browser is responsible for handling
				// the problem, which browsers like Chrome and Firefox already
				// know to do.
				//
				// See https://code.google.com/p/go/issues/detail?id=4677
				DisableKeepAlives: true,
				// TODO: would be good to make this sensitive to QOS, which
				// right now is only respected for HTTPS connections. The
				// challenge is that ReverseProxy reuses connections for
				// different requests, so we might have to configure different
				// ReverseProxies for different QOS's or something like that.
				Dial: bal.Dial,
			}),
		// Set a FlushInterval to prevent overly aggressive buffering of
		// responses, which helps keep memory usage down
		FlushInterval: 250 * time.Millisecond,
	}

	if client.rpInitialized {
		log.Trace("Draining reverse proxy channel")
		<-client.rpCh
	} else {
		log.Trace("Creating reverse proxy channel")
		client.rpCh = make(chan *httputil.ReverseProxy, 1)
	}
	log.Trace("Publishing reverse proxy")
	client.rpCh <- rp
}

// withDumpHeaders creates a RoundTripper that uses the supplied RoundTripper
// and that dumps headers is client is so configured.
func withDumpHeaders(shouldDumpHeaders bool, rt http.RoundTripper) http.RoundTripper {
	if !shouldDumpHeaders {
		return rt
	}
	return &headerDumpingRoundTripper{rt}
}

// headerDumpingRoundTripper is an http.RoundTripper that wraps another
// http.RoundTripper and dumps response headers to the log.
type headerDumpingRoundTripper struct {
	orig http.RoundTripper
}

func (rt *headerDumpingRoundTripper) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	proxy.DumpHeaders("Request", &req.Header)
	resp, err = rt.orig.RoundTrip(req)
	if err == nil {
		proxy.DumpHeaders("Response", &resp.Header)
	}
	return
}
