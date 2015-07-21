package client

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"runtime"
	"strconv"

	"github.com/getlantern/detour"
)

const (
	httpConnectMethod  = "CONNECT" // HTTP CONNECT method
	httpXFlashlightQOS = "X-Flashlight-QOS"
)

// ServeHTTP implements the method from interface http.Handler using the latest
// handler available from getHandler() and latest ReverseProxy available from
// getReverseProxy().
func (client *Client) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	if req.Method == httpConnectMethod {
		// CONNECT requests are often used for HTTPS requests.
		log.Tracef("Intercepting CONNECT %s", req.URL)
		client.intercept(resp, req)
	} else {
		// Direct proxying can only be used for plain HTTP connections.
		log.Tracef("Reverse proxying %s %v", req.Method, req.URL)
		client.getReverseProxy().ServeHTTP(resp, req)
	}
}

// intercept intercepts an HTTP CONNECT request, hijacks the underlying client
// connetion and starts piping the data over a new net.Conn obtained from the
// given dial function.
func (client *Client) intercept(resp http.ResponseWriter, req *http.Request) {

	if req.Method != httpConnectMethod {
		panic("Intercept used for non-CONNECT request!")
	}

	// Hijack underlying connection.
	clientConn, _, err := resp.(http.Hijacker).Hijack()
	defer func() {
		if err := clientConn.Close(); err != nil {
			log.Debugf("Error closing the client connection: %s", err)
		}
	}()
	if err != nil {
		respondBadGateway(resp, fmt.Sprintf("Unable to hijack connection: %s", err))
		return
	}

	// Establish outbound connection.
	addr := hostIncludingPort(req, 443)
	d := func(network, addr string) (net.Conn, error) {
		return client.getBalancer().DialQOS("tcp", addr, client.targetQOS(req))
	}

	var connOut net.Conn
	if runtime.GOOS == "android" || client.ProxyAll {
		connOut, err = d("tcp", addr)
	} else {
		connOut, err = detour.Dialer(d)("tcp", addr)
	}
	defer func() {
		if err := connOut.Close(); err != nil {
			log.Debugf("Error closing the out connection: %s", err)
		}
	}()
	if err != nil {
		respondBadGateway(clientConn, fmt.Sprintf("Unable to handle CONNECT request: %s", err))
		return
	}

	// Respond OK
	err = respondOK(clientConn, req)
	if err != nil {
		log.Errorf("Unable to respond OK: %s", err)
		return
	}

	// Pipe data between the client and the proxy. Will block until signaled within the function.
	signal := pipeData(clientConn, connOut)
	// Then, when this happens, this will unblock and deferred calls will take place.
	<-signal
}

// targetQOS determines the target quality of service given the X-Flashlight-QOS
// header if available, else returns MinQOS.
func (client *Client) targetQOS(req *http.Request) int {
	requestedQOS := req.Header.Get(httpXFlashlightQOS)

	if requestedQOS != "" {
		rqos, err := strconv.Atoi(requestedQOS)
		if err == nil {
			return rqos
		}
	}

	return client.MinQOS
}

// pipeData pipes data between the client and proxy connections.  It's also
// responsible for responding to the initial CONNECT request with a 200 OK.
func pipeData(clientConn net.Conn, connOut net.Conn) (signal chan bool) {
	signal = make(chan bool)

	// Start piping from client to proxy
	go func() {
		if _, err := io.Copy(connOut, clientConn); err != nil {
			log.Tracef("Error piping data from client to proxy: %s", err)
		}
		// Force closing if EOF at the request half or error encountered.
		// A bit arbitrary, but it's rather rare now to use half closing
		// as a way to notify server. Most application closes both connections
		// after completed send / receive so that won't cause problem.
		signal <- true
	}()

	// Then start coyping from proxy to client. This can be closed preemptively by
	// the other half.
	go func() {
		if _, err := io.Copy(clientConn, connOut); err != nil {
			log.Tracef("Error piping data from proxy to client: %s", err)
		}
	}()

	return
}

func respondOK(writer io.Writer, req *http.Request) error {
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

func respondBadGateway(w io.Writer, msg string) {
	log.Debugf("Responding BadGateway: %v", msg)
	resp := &http.Response{
		StatusCode: http.StatusBadGateway,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}
	err := resp.Write(w)
	if err == nil {
		if _, err = w.Write([]byte(msg)); err != nil {
			log.Debugf("Error writing error to io.Writer: %s", err)
		}
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
