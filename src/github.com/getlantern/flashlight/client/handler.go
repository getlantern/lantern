package client

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"runtime"
	"strconv"
	"sync"

	"github.com/getlantern/detour"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/fronted"
)

const (
	httpConnectMethod = "CONNECT" // HTTP CONNECT method
	frontedHeader     = "Lantern-Fronted-URL"
)

var (
	// This is for doing direct domain fronting if necessary. We store this as
	// an instance variable because it caches TLS session configs.
	direct = fronted.NewDirect()
)

// ServeHTTP implements the method from interface http.Handler using the latest
// handler available from getHandler() and latest ReverseProxy available from
// getReverseProxy().
func (client *Client) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	logging.RegisterUserAgent(req.Header.Get("User-Agent"))

	if req.Method == httpConnectMethod {
		// CONNECT requests are often used for HTTPS requests.
		log.Tracef("Intercepting CONNECT %s", req.URL)
		client.intercept(resp, req)
	} else {
		// Direct proxying can only be used for plain HTTP connections.
		client.serveHTTP(resp, req)
	}
}

func (client *Client) serveHTTP(resp http.ResponseWriter, req *http.Request) {
	if rp, err := client.newReverseProxy(); err == nil {
		log.Debugf("Reverse proxying %s %v", req.Method, req.URL)
		rp.ServeHTTP(resp, req)
		return
	}

	// If the request indicates we should also attempt to fulfill it through
	// domain fronting, do so here.
	frontedUrl := req.Header.Get(frontedHeader)
	if frontedUrl == "" {
		log.Debugf("No fronting header found for %v, skipping DDF", req.URL)
		respondBadGateway(resp, fmt.Sprintf("Unable get outgoing proxy connection"))
		return
	}
	serveHTTPWithDDF(resp, req, frontedUrl)
}

// serveHTTPWithDDF tries to serve the HTTP request using direct domain fronting.
// This will only work if the client has set the special header indicating the URL
// we should use for the fronted request.
func serveHTTPWithDDF(rw http.ResponseWriter, req *http.Request, frontedUrl string) {
	log.Debugf("Direct domain fronting to %v using fronted URL %v", req.URL, frontedUrl)
	client := direct.NewDirectHttpClient()
	if r, err := http.NewRequest(req.Method, frontedUrl, nil); err != nil {
		log.Errorf("Could not create request with URL: %v", frontedUrl)
		respondBadGateway(rw, fmt.Sprintf("Unable to create request: %s", err))
	} else if resp, err := client.Do(r); err != nil {
		respondBadGateway(rw, fmt.Sprintf("Unable get outgoing proxy connection: %s", err))
	} else {
		defer func() {
			if err := resp.Body.Close(); err != nil {
				log.Debugf("Could not close body %v", err)
			}
		}()

		// We have to hijack the connection to write directly to avoid some of the automated
		// response handling ResponseWriter does.
		if clientConn, _, err := rw.(http.Hijacker).Hijack(); err != nil {
			log.Errorf("Could not hijack connection to %s: %s", frontedUrl, err)
			respondBadGateway(rw, fmt.Sprintf("Unable to hijack connection: %s", err))
		} else {
			resp.Write(clientConn)
		}
	}
}

// intercept intercepts an HTTP CONNECT request, hijacks the underlying client
// connection and starts piping the data over a new net.Conn obtained from the
// given dial function.
func (client *Client) intercept(resp http.ResponseWriter, req *http.Request) {

	if req.Method != httpConnectMethod {
		panic("Intercept used for non-CONNECT request!")
	}

	var err error
	var clientConn net.Conn
	var connOut net.Conn

	// Make sure of closing connections only once
	var closeOnce sync.Once

	// Force closing if EOF at the request half or error encountered.
	// A bit arbitrary, but it's rather rare now to use half closing
	// as a way to notify server. Most application closes both connections
	// after completed send / receive so that won't cause problem.
	closeConns := func() {
		if clientConn != nil {
			if err := clientConn.Close(); err != nil {
				log.Debugf("Error closing the out connection: %s", err)
			}
		}
		if connOut != nil {
			if err := connOut.Close(); err != nil {
				log.Debugf("Error closing the client connection: %s", err)
			}
		}
	}

	defer closeOnce.Do(closeConns)

	// Hijack underlying connection.
	if clientConn, _, err = resp.(http.Hijacker).Hijack(); err != nil {
		respondBadGateway(resp, fmt.Sprintf("Unable to hijack connection: %s", err))
		return
	}

	// Respond OK as soon as possible, even if we don't have the outbound connection
	// established yet, to avoid timeouts on the client application
	success := make(chan bool, 1)
	go func() {
		if e := respondOK(clientConn, req); e != nil {
			log.Errorf("Unable to respond OK: %s", e)
			success <- false
			return
		}
		success <- true
	}()

	// Establish outbound connection.
	addr := hostIncludingPort(req, 443)
	d := func(network, addr string) (net.Conn, error) {
		// UGLY HACK ALERT! In this case, we know we need to send a CONNECT request
		// to the chained server. We need to send that request from chained/dialer.go
		// though because only it knows about the authentication token to use.
		// We signal it to send the CONNECT here using the network transport argument
		// that is effectively always "tcp" in the end, but we look for this
		// special "transport" in the dialer and send a CONNECT request in that
		// case.
		return client.getBalancer().Dial("connect", addr)
	}

	if runtime.GOOS == "android" || client.ProxyAll {
		connOut, err = d("tcp", addr)
	} else {
		connOut, err = detour.Dialer(d)("tcp", addr)
	}
	if err != nil {
		log.Debugf("Could not dial %v", err)
		return
	}

	if <-success {
		// Pipe data between the client and the proxy.
		pipeData(clientConn, connOut, func() { closeOnce.Do(closeConns) })
	}
}

// pipeData pipes data between the client and proxy connections.  It's also
// responsible for responding to the initial CONNECT request with a 200 OK.
func pipeData(clientConn net.Conn, connOut net.Conn, closeFunc func()) {
	// Start piping from client to proxy
	go func() {
		if _, err := io.Copy(connOut, clientConn); err != nil {
			log.Tracef("Error piping data from client to proxy: %s", err)
		}
		closeFunc()
	}()

	// Then start coyping from proxy to client.
	if _, err := io.Copy(clientConn, connOut); err != nil {
		log.Tracef("Error piping data from proxy to client: %s", err)
	}
}

func respondOK(writer io.Writer, req *http.Request) error {
	log.Debugf("Responding OK to %v", req.URL)
	defer func() {
		if err := req.Body.Close(); err != nil {
			log.Debugf("Error closing body of OK response: %s", err)
		}
	}()

	resp := &http.Response{
		StatusCode: http.StatusOK,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}

	return resp.Write(writer)
}

func respondBadGateway(resp http.ResponseWriter, msg string) {
	log.Debugf("Responding BadGateway: %v", msg)
	resp.WriteHeader(http.StatusBadGateway)
	if _, err := resp.Write([]byte(msg)); err != nil {
		log.Debugf("Error writing error to ResponseWriter: %s", err)
	}
}

// hostIncludingPort extracts the host:port from a request.  It fills in a
// a default port if none was found in the request.
func hostIncludingPort(req *http.Request, defaultPort int) string {
	_, port, err := net.SplitHostPort(req.Host)
	if port == "" || err != nil {
		return req.Host + ":" + strconv.Itoa(defaultPort)
	} else {
		return req.Host
	}
}
