package forward

import (
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/http-proxy/utils"
	"github.com/getlantern/idletiming"
)

var log = golog.LoggerFor("forward")

type Forwarder struct {
	errHandler   utils.ErrorHandler
	roundTripper http.RoundTripper
	rewriter     RequestRewriter
	next         http.Handler

	idleTimeout time.Duration
}

type optSetter func(f *Forwarder) error

func RoundTripper(r http.RoundTripper) optSetter {
	return func(f *Forwarder) error {
		f.roundTripper = r
		return nil
	}
}

type RequestRewriter interface {
	Rewrite(r *http.Request)
}

func Rewriter(r RequestRewriter) optSetter {
	return func(f *Forwarder) error {
		f.rewriter = r
		return nil
	}
}

func IdleTimeoutSetter(i time.Duration) optSetter {
	return func(f *Forwarder) error {
		f.idleTimeout = i
		return nil
	}
}

func New(next http.Handler, setters ...optSetter) (*Forwarder, error) {
	idleTimeoutPtr := new(time.Duration)
	dialerFunc := func(network, addr string) (net.Conn, error) {
		conn, err := net.DialTimeout(network, addr, time.Second*30)
		if err != nil {
			return nil, err
		}

		idleConn := idletiming.Conn(conn, *idleTimeoutPtr, func() {
			if conn != nil {
				conn.Close()
			}
		})
		return idleConn, err
	}

	var timeoutTransport http.RoundTripper = &http.Transport{
		Dial:                dialerFunc,
		TLSHandshakeTimeout: 10 * time.Second,
	}
	f := &Forwarder{
		errHandler:   utils.DefaultHandler,
		roundTripper: timeoutTransport,
		next:         next,
		idleTimeout:  30 * time.Second,
	}
	for _, s := range setters {
		if err := s(f); err != nil {
			return nil, err
		}
	}

	// Make sure we update the timeout that dialer is going to use
	*idleTimeoutPtr = f.idleTimeout

	if f.rewriter == nil {
		f.rewriter = &HeaderRewriter{
			TrustForwardHeader: true,
			Hostname:           "",
		}
	}

	return f, nil
}

func (f *Forwarder) ServeHTTP(w http.ResponseWriter, req *http.Request) {

	// Create a copy of the request suitable for our needs
	reqClone, err := f.cloneRequest(req, req.URL)
	if err != nil {
		log.Errorf("Error forwarding to %v, error: %v", req.Host, err)
		f.errHandler.ServeHTTP(w, req, err)
		return
	}
	f.rewriter.Rewrite(reqClone)

	if log.IsTraceEnabled() {
		reqStr, _ := httputil.DumpRequest(req, false)
		log.Tracef("Forwarder Middleware received request:\n%s", reqStr)

		reqStr2, _ := httputil.DumpRequest(reqClone, false)
		log.Tracef("Forwarder Middleware forwarding rewritten request:\n%s", reqStr2)
	}

	// Forward the request and get a response
	start := time.Now().UTC()
	response, err := f.roundTripper.RoundTrip(reqClone)
	if err != nil {
		log.Debugf("Error forwarding to %v, error: %v", req.Host, err)
		f.errHandler.ServeHTTP(w, req, err)
		return
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
		_, err = io.Copy(w, response.Body)
		if err != nil {
			log.Debug(err)
		}

		response.Body.Close()
	}
}

func (f *Forwarder) cloneRequest(req *http.Request, u *url.URL) (*http.Request, error) {
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
