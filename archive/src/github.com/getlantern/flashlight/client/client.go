package client

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/armon/go-socks5"
	"github.com/getlantern/appdir"
	"github.com/getlantern/detour"
	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
	"github.com/getlantern/netx"

	"github.com/getlantern/flashlight/ops"
)

const (
	// LanternSpecialDomain is a special domain for use by lantern that gets
	// resolved to localhost by the proxy
	LanternSpecialDomain          = "ui.lantern.io"
	lanternSpecialDomainWithColon = "ui.lantern.io:"
)

var (
	log = golog.LoggerFor("flashlight.client")

	// UIAddr is the address at which UI is to be found
	UIAddr string

	addr                = eventual.NewValue()
	socksAddr           = eventual.NewValue()
	proxiedCONNECTPorts = []int{
		// Standard HTTP(S) ports
		80, 443,
		// Common unprivileged HTTP(S) ports
		8080, 8443,
		// XMPP
		5222, 5223, 5224,
		// Android
		5228, 5229,
		// udpgw
		7300,
		// Google Hangouts TCP Ports (see https://support.google.com/a/answer/1279090?hl=en)
		19305, 19306, 19307, 19308, 19309,
	}
)

// Client is an HTTP proxy that accepts connections from local programs and
// proxies these via remote flashlight servers.
type Client struct {
	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	// Reverse proxy
	rp eventual.Value

	l net.Listener

	proxyAll func() bool
}

// NewClient creates a new client that does things like starts the HTTP and
// SOCKS proxies. It take a function for determing whether or not to proxy
// all traffic.
func NewClient(proxyAll func() bool) *Client {
	return &Client{
		rp:       eventual.NewValue(),
		proxyAll: proxyAll,
	}
}

// Addr returns the address at which the client is listening with HTTP, blocking
// until the given timeout for an address to become available.
func Addr(timeout time.Duration) (interface{}, bool) {
	return addr.Get(timeout)
}

// Addr returns the address at which the client is listening with HTTP, blocking
// until the given timeout for an address to become available.
func (client *Client) Addr(timeout time.Duration) (interface{}, bool) {
	return Addr(timeout)
}

// Socks5Addr returns the address at which the client is listening with SOCKS5,
// blocking until the given timeout for an address to become available.
func Socks5Addr(timeout time.Duration) (interface{}, bool) {
	return socksAddr.Get(timeout)
}

// Socks5Addr returns the address at which the client is listening with SOCKS5,
// blocking until the given timeout for an address to become available.
func (client *Client) Socks5Addr(timeout time.Duration) (interface{}, bool) {
	return Socks5Addr(timeout)
}

// ListenAndServeHTTP makes the client listen for HTTP connections at a the given
// address or, if a blank address is given, at a random port on localhost.
// onListeningFn is a callback that gets invoked as soon as the server is
// accepting TCP connections.
func (client *Client) ListenAndServeHTTP(requestedAddr string, onListeningFn func()) error {
	log.Debug("About to listen")
	if requestedAddr == "" {
		requestedAddr = "127.0.0.1:0"
	}

	var err error
	var l net.Listener
	if l, err = net.Listen("tcp", requestedAddr); err != nil {
		return fmt.Errorf("Unable to listen: %q", err)
	}

	client.l = l
	listenAddr := l.Addr().String()
	addr.Set(listenAddr)
	onListeningFn()

	httpServer := &http.Server{
		ReadTimeout:  client.ReadTimeout,
		WriteTimeout: client.WriteTimeout,
		Handler:      client,
		ErrorLog:     log.AsStdLogger(),
	}

	log.Debugf("About to start HTTP client proxy at %v", listenAddr)
	return httpServer.Serve(l)
}

// ListenAndServeSOCKS5 starts the SOCKS server listening at the specified
// address.
func (client *Client) ListenAndServeSOCKS5(requestedAddr string) error {
	var err error
	var l net.Listener
	if l, err = net.Listen("tcp", requestedAddr); err != nil {
		return fmt.Errorf("Unable to listen: %q", err)
	}
	listenAddr := l.Addr().String()
	socksAddr.Set(listenAddr)

	conf := &socks5.Config{
		Dial: func(network, addr string) (net.Conn, error) {
			port, portErr := client.portForAddress(addr)
			if portErr != nil {
				return nil, portErr
			}
			return client.dialCONNECT(addr, port)
		},
	}
	server, err := socks5.New(conf)
	if err != nil {
		return fmt.Errorf("Unable to create SOCKS5 server: %v", err)
	}

	log.Debugf("About to start SOCKS5 client proxy at %v", listenAddr)
	return server.Serve(l)
}

// Configure updates the client's configuration. Configure can be called
// before or after ListenAndServe, and can be called multiple times.
func (client *Client) Configure(proxies map[string]*ChainedServerInfo, deviceID string) {
	log.Debug("Configure() called")
	err := client.initBalancer(proxies, deviceID)
	if err != nil {
		log.Error(err)
	} else {
		client.rp.Set(client.newReverseProxy())
	}
}

// Stop is called when the client is no longer needed. It closes the
// client listener and underlying dialer connection pool
func (client *Client) Stop() error {
	return client.l.Close()
}

func (client *Client) proxiedDialer(orig func(network, addr string) (net.Conn, error)) func(network, addr string) (net.Conn, error) {
	detourDialer := detour.Dialer(orig)

	return func(network, addr string) (net.Conn, error) {
		op := ops.Begin("proxied_dialer")
		defer op.End()

		var proxied func(network, addr string) (net.Conn, error)
		if client.proxyAll() {
			op.Set("detour", false)
			proxied = orig
		} else {
			op.Set("detour", true)
			proxied = detourDialer
		}

		if isLanternSpecialDomain(addr) {
			rewritten := rewriteLanternSpecialDomain(addr)
			log.Tracef("Rewriting %v to %v", addr, rewritten)
			return net.Dial(network, rewritten)
		}
		start := time.Now()
		conn, err := proxied(network, addr)
		log.Debugf("Dialing proxy takes %v for %s", time.Since(start), addr)
		return conn, op.FailIf(err)
	}
}

func (client *Client) dialCONNECT(addr string, port int) (net.Conn, error) {
	// Establish outbound connection
	if client.shouldSendToProxy(addr, port) {
		log.Tracef("Proxying CONNECT request for %v", addr)
		d := client.proxiedDialer(func(network, addr string) (net.Conn, error) {
			// UGLY HACK ALERT! In this case, we know we need to send a CONNECT request
			// to the chained server. We need to send that request from chained/dialer.go
			// though because only it knows about the authentication token to use.
			// We signal it to send the CONNECT here using the network transport argument
			// that is effectively always "tcp" in the end, but we look for this
			// special "transport" in the dialer and send a CONNECT request in that
			// case.
			return bal.Dial("connect", addr)
		})
		return d("tcp", addr)
	}
	log.Tracef("Port not allowed, bypassing proxy and sending CONNECT request directly to %v", addr)
	return netx.DialTimeout("tcp", addr, 1*time.Minute)
}

func (client *Client) shouldSendToProxy(addr string, port int) bool {
	if isLanternSpecialDomain(addr) {
		return true
	}
	for _, proxiedPort := range proxiedCONNECTPorts {
		if port == proxiedPort {
			return true
		}
	}
	return false
}

func (client *Client) portForAddress(addr string) (int, error) {
	_, portString, err := net.SplitHostPort(addr)
	if err != nil {
		return 0, fmt.Errorf("Unable to determine port for address %v: %v", addr, err)
	}
	port, err := strconv.Atoi(portString)
	if err != nil {
		return 0, fmt.Errorf("Unable to parse port %v for address %v: %v", addr, port, err)
	}
	return port, nil
}

func isLanternSpecialDomain(addr string) bool {
	return strings.Index(addr, lanternSpecialDomainWithColon) == 0
}

func rewriteLanternSpecialDomain(addr string) string {
	return UIAddr
}

// InConfigDir returns the path of the specified file name in the Lantern
// configuration directory, using an alternate base configuration directory
// if necessary for things like testing.
func InConfigDir(configDir string, filename string) (string, error) {
	cdir := configDir

	if cdir == "" {
		cdir = appdir.General("Lantern")
	}

	log.Debugf("Using config dir %v", cdir)
	if _, err := os.Stat(cdir); err != nil {
		if os.IsNotExist(err) {
			// Create config dir
			if err := os.MkdirAll(cdir, 0750); err != nil {
				return "", fmt.Errorf("Unable to create configdir at %s: %s", cdir, err)
			}
		}
	}

	return filepath.Join(cdir, filename), nil
}
