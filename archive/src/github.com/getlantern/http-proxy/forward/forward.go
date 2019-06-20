package forward

import (
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/idletiming"
	"github.com/getlantern/ops"

	"github.com/getlantern/http-proxy/buffers"
	"github.com/getlantern/http-proxy/filters"
)

var log = golog.LoggerFor("forward")

type Options struct {
	IdleTimeout  time.Duration
	Rewriter     RequestRewriter
	RoundTripper http.RoundTripper
}

type forwarder struct {
	*Options
}

type RequestRewriter interface {
	Rewrite(r *http.Request)
}

func New(opts *Options) filters.Filter {
	if opts.Rewriter == nil {
		opts.Rewriter = &HeaderRewriter{
			TrustForwardHeader: true,
			Hostname:           "",
		}
	}

	if opts.RoundTripper == nil {
		dialerFunc := func(network, addr string) (net.Conn, error) {
			conn, err := net.DialTimeout(network, addr, time.Second*30)
			if err != nil {
				return nil, err
			}

			idleConn := idletiming.Conn(conn, opts.IdleTimeout, nil)
			return idleConn, err
		}

		timeoutTransport := &http.Transport{
			Dial:                dialerFunc,
			TLSHandshakeTimeout: 10 * time.Second,
			MaxIdleTime:         opts.IdleTimeout / 2, // remove idle keep-alive connections to avoid leaking memory
		}
		timeoutTransport.EnforceMaxIdleTime()
		opts.RoundTripper = timeoutTransport
	}

	return &forwarder{opts}
}

func (f *forwarder) Apply(w http.ResponseWriter, req *http.Request, next filters.Next) error {
	op := ops.Begin("proxy_http")
	defer op.End()

	// Create a copy of the request suitable for our needs
	reqClone, err := f.cloneRequest(req, req.URL)
	if err != nil {
		return op.FailIf(filters.Fail("Error forwarding from %v to %v: %v", req.RemoteAddr, req.Host, err))
	}
	f.Rewriter.Rewrite(reqClone)

	if log.IsTraceEnabled() {
		reqStr, _ := httputil.DumpRequest(req, false)
		log.Tracef("Forwarder Middleware received request:\n%s", reqStr)

		reqStr2, _ := httputil.DumpRequest(reqClone, false)
		log.Tracef("Forwarder Middleware forwarding rewritten request:\n%s", reqStr2)
	}

	// Forward the request and get a response
	start := time.Now().UTC()
	response, err := f.RoundTripper.RoundTrip(reqClone)
	if err != nil {
		return op.FailIf(filters.Fail("Error forwarding from %v to %v: %v", req.RemoteAddr, req.Host, err))
	}
	log.Debugf("Round trip: %v, code: %v, duration: %v",
		reqClone.URL, response.StatusCode, time.Now().UTC().Sub(start))

	if log.IsTraceEnabled() {
		respStr, _ := httputil.DumpResponse(response, true)
		log.Tracef("Forward Middleware received response:\n%s", respStr)
	}

	// Forward the response to the origin
	copyHeadersForForwarding(w.Header(), response.Header)
	w.WriteHeader(response.StatusCode)

	// It became nil in a Co-Advisor test though the doc says it will never be nil
	if response.Body != nil {
		buf := buffers.Get()
		defer buffers.Put(buf)
		_, err = io.CopyBuffer(w, response.Body, buf)
		if err != nil {
			log.Debug(err)
		}

		response.Body.Close()
	}

	return filters.Stop()
}

func (f *forwarder) cloneRequest(req *http.Request, u *url.URL) (*http.Request, error) {
	outReq := new(http.Request)
	// Beware, this will make a shallow copy. We have to copy all maps
	*outReq = *req

	outReq.Proto = "HTTP/1.1"
	outReq.ProtoMajor = 1
	outReq.ProtoMinor = 1
	// Overwrite close flag: keep persistent connection for the backend servers
	outReq.Close = false

	// Request Header
	outReq.Header = make(http.Header)
	copyHeadersForForwarding(outReq.Header, req.Header)
	// Ensure we have a HOST header (important for Go 1.6+ because http.Server
	// strips the HOST header from the inbound request)
	outReq.Header.Set("Host", req.Host)

	// Request URL
	outReq.URL = cloneURL(req.URL)
	// We know that is going to be HTTP always because HTTPS isn't forwarded.
	// We need to hardcode it here because req.URL.Scheme can be undefined, since
	// client request don't need to use absolute URIs
	outReq.URL.Scheme = "http"
	// We need to make sure the host is defined in the URL (not the actual URI)
	outReq.URL.Host = req.Host
	outReq.URL.RawQuery = req.URL.RawQuery

	userAgent := req.UserAgent()
	if userAgent == "" {
		outReq.Header.Del("User-Agent")
	} else {
		outReq.Header.Set("User-Agent", userAgent)
	}

	/*
		// Trailer support
		// We are forced to do this because Go's server won't allow us to read the trailers otherwise
		_, err := httputil.DumpRequestOut(req, true)
		if err != nil {
		  log.Errorf("Error: %v", err)
		  return outReq, err
		}

		rcloser := ioutil.NopCloser(req.Body)
		outReq.Body = rcloser

		chunkedTransfer := false
		for _, enc := range req.TransferEncoding {
		  if enc == "chunked" {
		    chunkedTransfer = true
		    break
		  }
		}

		// Append Trailer
		if chunkedTransfer && len(req.Trailer) > 0 {
		  outReq.Trailer = http.Header{}
		  for k, vv := range req.Trailer {
		    for _, v := range vv {
		      outReq.Trailer.Add(k, v)
		    }
		  }
		}
	*/

	return outReq, nil
}
