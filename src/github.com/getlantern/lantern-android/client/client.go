package client

import (
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"strconv"
	"sync"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/flashlight/util"
)

const (
	cloudConfigPollInterval = time.Second * 60
	httpConnectMethod       = "CONNECT"
	httpXFlashlightQOS      = "X-Flashlight-QOS"
)

// clientConfig holds global configuration settings for all clients.
var clientConfig *config

// init attempts to setup client configuration.
func init() {
	var err error
	// Initial attempt to get configuration, without a proxy. If this request
	// fails we'll use the default configuration.
	if clientConfig, err = getConfig(); err != nil {
		// getConfig() guarantees to return a *Config struct, so we can log the
		// error without stopping the program.
		log.Printf("Error updating configuration over the network: %q.", err)
	}
}

// Client is a HTTP proxy that accepts connections from local programs and
// proxies these via remote flashlight servers.
type Client struct {
	addr string
	cfg  config

	ln net.Listener

	rpCh          chan *httputil.ReverseProxy
	rpInitialized bool

	balInitialized bool
	balCh          chan *balancer.Balancer
	cfgMu          sync.RWMutex

	closed chan bool
}

// NewClient creates a proxy client.
func NewClient(addr string) *Client {
	client := &Client{addr: addr}

	client.cfg = *clientConfig
	client.reloadConfig()

	return client
}

func (client *Client) reloadConfig() {
	// We can only run one reset task at a time.
	client.cfgMu.Lock()
	defer client.cfgMu.Unlock()

	// Starting up balancer.
	client.initBalancer()

	// Starting reverse proxy.
	client.initReverseProxy()
}

// updateConfig attempts to pull a configuration file from the network using
// the client proxy itself.
func (client *Client) updateConfig() error {
	var err error
	var buf []byte
	var cli *http.Client

	if cli, err = util.HTTPClient(cloudConfigCA, client.addr); err != nil {
		return err
	}

	if buf, err = pullConfigFile(cli); err != nil {
		return err
	}

	return client.cfg.updateFrom(buf)
}

// ServeHTTP implements the method from interface http.Handler using the latest
// handler available from getHandler() and latest ReverseProxy available from
// getReverseProxy().
func (client *Client) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	if req.Method == httpConnectMethod {
		client.intercept(resp, req)
	} else {
		client.getReverseProxy().ServeHTTP(resp, req)
	}
}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *Client) pollConfiguration() {
	pollTimer := time.NewTimer(cloudConfigPollInterval)
	defer pollTimer.Stop()

	for {
		select {
		case <-client.closed:
			return
		case <-pollTimer.C:
			// Attempt to update configuration.
			var err error
			if err = client.updateConfig(); err == nil {
				// Configuration changed, lets reload.
				client.reloadConfig()
			}
			// Sleeping 'till next pull.
			pollTimer.Reset(cloudConfigPollInterval)
		}
	}

}

// ListenAndServe spawns the HTTP proxy and makes it listen for incoming
// connections.
func (client *Client) ListenAndServe() (err error) {
	addr := client.addr

	if addr == "" {
		addr = ":http"
	}

	if client.ln, err = net.Listen("tcp", addr); err != nil {
		return err
	}

	client.closed = make(chan bool)

	defer func() {
		close(client.closed)
	}()

	httpServer := &http.Server{
		Addr:    client.addr,
		Handler: client,
	}

	log.Printf("Starting proxy server at %s...", addr)

	go client.pollConfiguration()

	return httpServer.Serve(client.ln)
}

func targetQOS(req *http.Request) int {
	requestedQOS := req.Header.Get(httpXFlashlightQOS)
	if requestedQOS != "" {
		rqos, err := strconv.Atoi(requestedQOS)
		if err == nil {
			return rqos
		}
	}
	return 0
}

// intercept intercepts an HTTP CONNECT request, hijacks the underlying client
// connetion and starts piping the data over a new net.Conn obtained from the
// given dial function.
func (client *Client) intercept(resp http.ResponseWriter, req *http.Request) {
	if req.Method != httpConnectMethod {
		panic("Intercept used for non-CONNECT request!")
	}

	// Hijack underlying connection
	clientConn, _, err := resp.(http.Hijacker).Hijack()
	if err != nil {
		respondBadGateway(resp, fmt.Sprintf("Unable to hijack connection: %s", err))
		return
	}
	defer clientConn.Close()

	addr := hostIncludingPort(req, 443)

	// Establish outbound connection
	connOut, err := client.getBalancer().DialQOS("tcp", addr, targetQOS(req))
	if err != nil {
		respondBadGateway(clientConn, fmt.Sprintf("Unable to handle CONNECT request: %s", err))
		return
	}
	defer connOut.Close()

	// Pipe data
	pipeData(clientConn, connOut, req)
}

// Stop is currently not implemented but should make the listener stop
// accepting new connections and then kill all active connections.
func (client *Client) Stop() error {
	log.Printf("Stopping proxy server...")
	return client.ln.Close()
}

func respondBadGateway(w io.Writer, msg string) error {
	log.Printf("Responding BadGateway: %v", msg)
	resp := &http.Response{
		StatusCode: http.StatusBadGateway,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}
	err := resp.Write(w)
	if err == nil {
		_, err = w.Write([]byte(msg))
	}
	return err
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

// pipeData pipes data between the client and proxy connections.  It's also
// responsible for responding to the initial CONNECT request with a 200 OK.
func pipeData(clientConn net.Conn, connOut net.Conn, req *http.Request) {
	// Start piping to proxy
	go io.Copy(connOut, clientConn)

	// Respond OK
	err := respondOK(clientConn, req)
	if err != nil {
		log.Printf("Unable to respond OK: %s", err)
		return
	}

	// Then start coyping from out to client
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
