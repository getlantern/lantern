package client

import (
	"fmt"
	"net"
	"net/http"
	"reflect"
	"sync"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("flashlight.client")

	addr = eventual.NewValue()
)

// Client is an HTTP proxy that accepts connections from local programs and
// proxies these via remote flashlight servers.
type Client struct {
	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	// ProxyAll: (optional) proxy all sites regardless of being blocked or not
	ProxyAll func() bool

	// MinQOS: (optional) the minimum QOS to require from proxies.
	MinQOS int

	// Unique identifier for this device
	DeviceID string

	priorCfg *ClientConfig
	cfgMutex sync.RWMutex

	// Balanced CONNECT dialers.
	bal eventual.Value

	// Reverse proxy
	rp eventual.Value

	l net.Listener
}

func NewClient() *Client {
	return &Client{
		bal: eventual.NewValue(),
		rp:  eventual.NewValue(),
	}
}

// Addr returns the address at which the client is listening, blocking until the
// given timeout for an address to become available.
func Addr(timeout time.Duration) (interface{}, bool) {
	return addr.Get(timeout)
}

func (c *Client) Addr(timeout time.Duration) (interface{}, bool) {
	return Addr(timeout)
}

// ListenAndServe makes the client listen for HTTP connections at a the given
// address or, if a blank address is given, at a random port on localhost.
// onListeningFn is a callback that gets invoked as soon as the server is
// accepting TCP connections.
func (client *Client) ListenAndServe(requestedAddr string, onListeningFn func()) error {
	log.Debug("About to listen")
	var err error
	var l net.Listener

	if requestedAddr == "" {
		requestedAddr = "localhost:0"
	}

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

	log.Debugf("About to start client (HTTP) proxy at %s", listenAddr)
	return httpServer.Serve(l)
}

// Configure updates the client's configuration. Configure can be called
// before or after ListenAndServe, and can be called multiple times.
func (client *Client) Configure(cfg *ClientConfig, proxyAll func() bool) {
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
	client.MinQOS = cfg.MinQOS
	log.Debugf("Proxy all traffic or not: %v", proxyAll())
	client.ProxyAll = proxyAll
	client.DeviceID = cfg.DeviceID

	bal, err := client.initBalancer(cfg)
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
