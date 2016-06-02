package client

import (
	"fmt"
	"net"
	"net/http"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/armon/go-socks5"
	"github.com/getlantern/detour"
	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
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

	addr      = eventual.NewValue()
	socksAddr = eventual.NewValue()
)

// Client is an HTTP proxy that accepts connections from local programs and
// proxies these via remote flashlight servers.
type Client struct {
	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	cfgHolder atomic.Value
	priorCfg  *ClientConfig
	cfgMutex  sync.RWMutex

	// Balanced CONNECT dialers.
	bal eventual.Value

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
		bal:      eventual.NewValue(),
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
			port, err := client.portForAddress(addr)
			if err != nil {
				return nil, err
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
func (client *Client) Configure(cfg *ClientConfig, deviceID string) {
	client.cfgMutex.Lock()
	defer client.cfgMutex.Unlock()

	log.Debug("Configure() called")

	if client.priorCfg != nil {
		if reflect.DeepEqual(client.priorCfg, cfg) {
			log.Debugf("Client configuration unchanged")
			return
		}
		log.Debugf("Client configuration changed")
	} else {
		log.Debugf("Client configuration initialized")
	}

	log.Debugf("Requiring minimum QOS of %d", cfg.MinQOS)
	client.cfgHolder.Store(cfg)

	bal, err := client.initBalancer(cfg, deviceID)
	if err != nil {
		log.Error(err)
	} else if bal != nil {
		client.rp.Set(client.newReverseProxy(bal))
	}

	client.priorCfg = cfg
}

// Stop is called when the client is no longer needed. It closes the
// client listener and underlying dialer connection pool
func (client *Client) Stop() error {
	return client.l.Close()
}

func (client *Client) cfg() *ClientConfig {
	return client.cfgHolder.Load().(*ClientConfig)
}

func (client *Client) proxiedDialer(orig func(network, addr string) (net.Conn, error)) func(network, addr string) (net.Conn, error) {
	detourDialer := detour.Dialer(orig)

	return func(network, addr string) (net.Conn, error) {
		var proxied func(network, addr string) (net.Conn, error)
		if client.proxyAll() {
			proxied = orig
		} else {
			proxied = detourDialer
		}

		if isLanternSpecialDomain(addr) {
			rewritten := rewriteLanternSpecialDomain(addr)
			log.Tracef("Rewriting %v to %v", addr, rewritten)
			return net.Dial(network, rewritten)
		}
		return proxied(network, addr)
	}
}

func (client *Client) dialCONNECT(addr string, port int) (net.Conn, error) {
	// Establish outbound connection
	if client.shouldSendToProxy(port) {
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
		return d("tcp", addr)
	}
	log.Tracef("Port not allowed, bypassing proxy and sending CONNECT request directly to %v", addr)
	return dialDirect("tcp", addr, 1*time.Minute)
}

func (client *Client) shouldSendToProxy(port int) bool {
	for _, proxiedPort := range client.cfg().ProxiedCONNECTPorts {
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
	return strings.HasPrefix(addr, lanternSpecialDomainWithColon)
}

func rewriteLanternSpecialDomain(addr string) string {
	if addr == lanternSpecialDomainWithColon+"80" {
		// This is a special replacement for the ui.lantern.io:80 case.
		return "127.0.0.1:16823"
	}
	// Let any other port pass as is.
	addr = strings.Replace(addr, lanternSpecialDomainWithColon, "127.0.0.1:", 1)
	return addr
}
