package client

import (
	"fmt"
	"io"
	"net"
	"net/http"
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
		// CONNECT requests are often used for HTTPs requests.
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
	var err error

	// intercept can only by used for CONNECT requests.
	if req.Method != httpConnectMethod {
		panic("Intercept used for non-CONNECT request!")
	}

	// Hijacking underlying connection.
	var clientConn net.Conn
	if clientConn, _, err = resp.(http.Hijacker).Hijack(); err != nil {
		respondBadGateway(resp, fmt.Sprintf("Unable to hijack connection: %s", err))
		return
	}
	defer clientConn.Close()

	// Getting destination host and port.
	var host, port string

	if host, port, err = net.SplitHostPort(req.Host); err != nil {
		log.Tracef("net.SplitHostPort: %q", err)
	}

	// If no port is given, assuming it's 443 for HTTPs.
	if port == "" {
		port = "443"
	}

	// Creating a network address.
	addr := host + ":" + port

	// Establishing outbound connection with the given address.
	d := func(network, addr string) (net.Conn, error) {
		return client.getBalancer().DialQOS("tcp", addr, client.targetQOS(req))
	}

	// The actual dialer must pass through detour.
	var connOut net.Conn
	if connOut, err = detour.Dialer(d)("tcp", addr); err != nil {
		respondBadGateway(clientConn, fmt.Sprintf("Unable to handle CONNECT request: %s", err))
		return
	}

	defer connOut.Close()

	// Piping data between the client and the proxy.
	pipeData(clientConn, connOut, req)
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
func pipeData(clientConn net.Conn, connOut net.Conn, req *http.Request) {
	// Start piping from client to proxy
	go io.Copy(connOut, clientConn)

	// Respond OK
	if err := respondOK(clientConn, req); err != nil {
		log.Errorf("Unable to respond OK: %s", err)
		return
	}

	// Then start coyping from proxy to client
	io.Copy(clientConn, connOut)
}

func respondOK(writer io.Writer, req *http.Request) error {
	defer req.Body.Close()

	resp := &http.Response{
		StatusCode: http.StatusOK,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}

	return resp.Write(writer)
}

func respondBadGateway(w io.Writer, msg string) (err error) {
	log.Debugf("Responding BadGateway: %v", msg)
	resp := &http.Response{
		StatusCode: http.StatusBadGateway,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}
	err = resp.Write(w)
	if err == nil {
		_, err = w.Write([]byte(msg))
	}
	return err
}
