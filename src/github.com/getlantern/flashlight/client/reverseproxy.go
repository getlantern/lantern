package client

import (
	"bytes"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"runtime"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/detour"
	"github.com/getlantern/flashlight/proxy"
	"github.com/getlantern/flashlight/status"
)

// authTransport allows us to override request headers for authentication and for
// stripping X-Forwarded-For
type authTransport struct {
	http.Transport
	balancedDialer *balancer.Dialer
}

// We need to set the authentication token for the server we're connecting to,
// and we also need to strip out X-Forwarded-For that reverseproxy adds because
// it confuses the upstream servers with the additional 127.0.0.1 field when
// upstream servers are trying to determin the client IP.
func (at *authTransport) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	norm := new(http.Request)
	*norm = *req // includes shallow copies of maps, but okay
	norm.Header.Del("X-Forwarded-For")
	norm.Header.Set("X-LANTERN-AUTH-TOKEN", at.balancedDialer.AuthToken)
	return at.Transport.RoundTrip(norm)
}

// newReverseProxy creates a reverse proxy that attempts to exit with any of
// the dialers provided by the balancer.
func (client *Client) newReverseProxy() (*httputil.ReverseProxy, error) {

	// This is a bit unorthodox in that we get a load balanced connection
	// first and then simply return that in our dial function below.
	// The reason for this is that the only the dialer knows the
	// authentication token for its associated server, and we need to
	// set that in the Transport RoundTrip call above.
	dialer, conn, err := client.getBalancer().TrustedDialerAndConn()
	if err != nil {
		// The internal code has already reported an error here.
		log.Debugf("Could not get balanced dialer %v", err)
		return nil, err
	}

	// We we simply return the already-established connection - see
	// above comment.
	dial := func(network, addr string) (net.Conn, error) {
		return conn, err
	}

	transport := &authTransport{
		balancedDialer: dialer,
	}
	// We disable keepalives because some servers pretend to support
	// keep-alives but close their connections immediately, which
	// causes an error inside ReverseProxy.  This is not an issue
	// for HTTPS because  the browser is responsible for handling
	// the problem, which browsers like Chrome and Firefox already
	// know to do.
	//
	// See https://code.google.com/p/go/issues/detail?id=4677
	transport.DisableKeepAlives = true
	transport.TLSHandshakeTimeout = 40 * time.Second

	// TODO: would be good to make this sensitive to QOS, which
	// right now is only respected for HTTPS connections. The
	// challenge is that ReverseProxy reuses connections for
	// different requests, so we might have to configure different
	// ReverseProxies for different QOS's or something like that.
	if runtime.GOOS == "android" || client.ProxyAll {
		transport.Dial = dial
	} else {
		transport.Dial = detour.Dialer(dial)
	}

	rp := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			// do nothing
		},
		Transport: &errorRewritingRoundTripper{
			withDumpHeaders(false, transport),
		},
		// Set a FlushInterval to prevent overly aggressive buffering of
		// responses, which helps keep memory usage down
		FlushInterval: 250 * time.Millisecond,
		ErrorLog:      log.AsStdLogger(),
	}

	return rp, nil
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
		// we will only return a ErrorAccessingPage error.  This prevents the user
		// from getting just a blank screen.
		htmlerr, err := status.ErrorAccessingPage(req.Host, err)

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
