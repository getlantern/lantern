package client

import (
	"bytes"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"runtime"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/detour"
	"github.com/getlantern/flashlight/proxy"
	"github.com/getlantern/flashlight/status"
)

// getReverseProxy waits for a message from client.rpCh to arrive and then it
// writes it back to client.rpCh before returning it as a value. This way we
// always have a balancer at client.rpCh and, if we don't have one, it would
// block until one arrives.
func (client *Client) getReverseProxy() *httputil.ReverseProxy {
	rp := <-client.rpCh
	client.rpCh <- rp
	return rp
}

// initReverseProxy creates a reverse proxy that attempts to exit with any of
// the dialers provided by the balancer.
func (client *Client) initReverseProxy(bal *balancer.Balancer, dumpHeaders bool) {

	transport := &http.Transport{
		// We disable keepalives because some servers pretend to support
		// keep-alives but close their connections immediately, which
		// causes an error inside ReverseProxy.  This is not an issue
		// for HTTPS because  the browser is responsible for handling
		// the problem, which browsers like Chrome and Firefox already
		// know to do.
		//
		// See https://code.google.com/p/go/issues/detail?id=4677
		DisableKeepAlives: true,
	}

	// TODO: would be good to make this sensitive to QOS, which
	// right now is only respected for HTTPS connections. The
	// challenge is that ReverseProxy reuses connections for
	// different requests, so we might have to configure different
	// ReverseProxies for different QOS's or something like that.
	if runtime.GOOS == "android" || client.ProxyAll {
		transport.Dial = bal.Dial
	} else {
		transport.Dial = detour.Dialer(bal.Dial)
	}

	rp := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			// do nothing
		},
		Transport: &errorRewritingRoundTripper{
			withDumpHeaders(dumpHeaders, transport),
		},
		// Set a FlushInterval to prevent overly aggressive buffering of
		// responses, which helps keep memory usage down
		FlushInterval: 250 * time.Millisecond,
		ErrorLog:      log.AsStdLogger(),
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

	// We don't need to protect client.rpInitialized from race conditions because
	// it's only accessed here in initReverseProxy, which always gets called
	// under Configure, which never gets called concurrently with itself.
	client.rpInitialized = true
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

// The errorRewritingRoundTripper writes creates an special *http.Response when
// the roundtripper fails for some reason.
type errorRewritingRoundTripper struct {
	orig http.RoundTripper
}

func (er *errorRewritingRoundTripper) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	res, err := er.orig.RoundTrip(req)
	if err != nil {

		// It is likely we will have lots of different errors to handle but for now
		// we will only return a CannotFindServer error.  This prevents the user
		// from getting just a blank screen.
		htmlerr, err := status.CannotFindServer(req.Host, err)

		if err != nil {
			log.Debugf("Got error while generating status page: %q", err)
		}

		res = &http.Response{
			Body: ioutil.NopCloser(bytes.NewBuffer(htmlerr)),
		}

		res.StatusCode = http.StatusServiceUnavailable
		return res, nil
	}
	return res, err
}
