package client

import (
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"strconv"
	"sync"
	"time"

	"github.com/getlantern/errors"
	"github.com/getlantern/flashlight/ops"
)

const (
	httpConnectMethod = "CONNECT" // HTTP CONNECT method
)

// ServeHTTP implements the method from interface http.Handler using the latest
// handler available from getHandler() and latest ReverseProxy available from
// getReverseProxy().
func (client *Client) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	userAgent := req.Header.Get("User-Agent")

	op := ops.Enter("proxy").
		UserAgent(userAgent).
		Origin(req.Host)
	defer op.Exit()

	if req.Method == httpConnectMethod {
		// CONNECT requests are often used for HTTPS requests.
		log.Tracef("Intercepting CONNECT %s", req.URL)
		client.intercept(resp, req, op)
	} else if rp, ok := client.rp.Get(1 * time.Minute); ok {
		// Direct proxying can only be used for plain HTTP connections.
		log.Debugf("Reverse proxying %s %v", req.Method, req.URL)
		rp.(*httputil.ReverseProxy).ServeHTTP(resp, req)
	} else {
		log.Debugf("Could not get a reverse proxy connection -- responding bad gateway")
		respondBadGateway(resp, op.Error(errors.New("Unable to get a connection")))
	}
}

// intercept intercepts an HTTP CONNECT request, hijacks the underlying client
// connection and starts piping the data over a new net.Conn obtained from the
// given dial function.
func (client *Client) intercept(resp http.ResponseWriter, req *http.Request, op *ops.Op) {
	if req.Method != httpConnectMethod {
		panic("Intercept used for non-CONNECT request!")
	}

	addr := hostIncludingPort(req, 443)
	_, portString, err := net.SplitHostPort(addr)
	if err != nil {
		respondBadGateway(resp, op.Error(errors.New("Unable to determine port for address %v: %v", addr, err)))
		return
	}
	port, err := strconv.Atoi(portString)
	if err != nil {
		respondBadGateway(resp, op.Error(errors.New("Unable to parse port %v for address %v: %v", addr, port, err)))
		return
	}

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
			if closeErr := clientConn.Close(); closeErr != nil {
				log.Debugf("Error closing the out connection: %s", closeErr)
			}
		}
		if connOut != nil {
			if closeErr := connOut.Close(); closeErr != nil {
				log.Debugf("Error closing the client connection: %s", closeErr)
			}
		}
	}

	defer closeOnce.Do(closeConns)

	// Hijack underlying connection.
	if clientConn, _, err = resp.(http.Hijacker).Hijack(); err != nil {
		respondBadGateway(resp, op.Error(errors.New("Unable to hijack connection: %s", err)))
		return
	}

	sendToProxy := false
	for _, proxiedPort := range client.cfg().ProxiedCONNECTPorts {
		if port == proxiedPort {
			sendToProxy = true
			break
		}
	}

	// Establish outbound connection
	if sendToProxy {
		log.Tracef("Proxying CONNECT request for %v", addr)
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
	} else {
		log.Tracef("Port not allowed, bypassing proxy and sending CONNECT request directly to %v", addr)
		connOut, err = net.Dial("tcp", addr)
	}

	if err != nil {
		log.Debug(op.Error(errors.New("Could not dial %v", err)))
		respondBadGatewayHijacked(clientConn, req)
		return
	}

	success := make(chan bool, 1)
	op.Go(func() {
		if e := respondOK(clientConn, req); e != nil {
			log.Error(op.Error(errors.New("Unable to respond OK: %s", e)))
			success <- false
			return
		}
		success <- true
	})

	if <-success {
		// Pipe data between the client and the proxy.
		pipeData(clientConn, connOut, op, func() { closeOnce.Do(closeConns) })
	}
}

// pipeData pipes data between the client and proxy connections.  It's also
// responsible for responding to the initial CONNECT request with a 200 OK.
func pipeData(clientConn net.Conn, connOut net.Conn, op *ops.Op, closeFunc func()) {
	writeErrCh := make(chan error)
	// Start piping from client to proxy
	op.Go(func() {
		_, writeErr := io.Copy(connOut, clientConn)
		if writeErr != nil {
			writeErrCh <- writeErr
		}
	})

	// Then start copying from proxy to client.
	_, readErr := io.Copy(clientConn, connOut)
	writeErr := <-writeErrCh
	if readErr != nil {
		log.Error(op.Error(errors.New("Error piping data from proxy to client: %v", readErr)))
	} else if writeErr != nil {
		log.Error(errors.New("Error piping data from client to proxy: %v", writeErr))
	}

	closeFunc()
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

func respondBadGateway(resp http.ResponseWriter, err error) {
	log.Debugf("Responding BadGateway: %v", err)
	resp.WriteHeader(http.StatusBadGateway)
	if _, writeError := resp.Write([]byte(err.Error())); writeError != nil {
		log.Debugf("Error writing error to ResponseWriter: %v", writeError)
	}
}

// hostIncludingPort extracts the host:port from a request.  It fills in a
// a default port if none was found in the request.
func hostIncludingPort(req *http.Request, defaultPort int) string {
	_, port, err := net.SplitHostPort(req.Host)
	if port == "" || err != nil {
		return req.Host + ":" + strconv.Itoa(defaultPort)
	}
	return req.Host
}
