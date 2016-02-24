package client

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"strconv"
	"sync"
	"time"

	"github.com/getlantern/flashlight/logging"
)

const (
	httpConnectMethod = "CONNECT" // HTTP CONNECT method
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
	} else if rp, ok := client.rp.Get(1 * time.Minute); ok {
		// Direct proxying can only be used for plain HTTP connections.
		log.Debugf("Reverse proxying %s %v", req.Method, req.URL)
		rp.(*httputil.ReverseProxy).ServeHTTP(resp, req)
	} else {
		log.Debugf("Could not get a reverse proxy connection -- responding bad gateway")
		respondBadGateway(resp, "Unable to get a connection")
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

	// Establish outbound connection.
	addr := hostIncludingPort(req, 443)
	d := client.proxiedDialer(func(network, addr string) (net.Conn, error) {
		// UGLY HACK ALERT! In this case, we know we need to send a CONNECT request
		// to the chained server. We need to send that request from chained/dialer.go
		// though because only it knows about the authentication token to use.
		// We signal it to send the CONNECT here using the network transport argument
		// that is effectively always "tcp" in the end, but we look for this
		// special "transport" in the dialer and send a CONNECT request in that
		// case.
		return client.getBalancer().Dial("connect", addr)
	})

	connOut, err = d("tcp", addr)
	if err != nil {
		log.Debugf("Could not dial %v", err)
		respondBadGatewayHijacked(clientConn, req)
		return
	}

	success := make(chan bool, 1)
	go func() {
		if e := respondOK(clientConn, req); e != nil {
			log.Errorf("Unable to respond OK: %s", e)
			success <- false
			return
		}
		success <- true
	}()

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
	return respondHijacked(writer, req, http.StatusOK)
}

func respondBadGatewayHijacked(writer io.Writer, req *http.Request) error {
	return respondHijacked(writer, req, http.StatusBadGateway)
}

func respondHijacked(writer io.Writer, req *http.Request, statusCode int) error {
	log.Debugf("Responding %v to %v", statusCode, req.URL)
	defer func() {
		if err := req.Body.Close(); err != nil {
			log.Debugf("Error closing body of OK response: %s", err)
		}
	}()

	resp := &http.Response{
		StatusCode: statusCode,
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
