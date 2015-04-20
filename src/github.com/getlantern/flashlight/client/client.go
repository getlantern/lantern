package client

import (
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"reflect"
	"sync"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/globals"
)

var (
	log = golog.LoggerFor("flashlight.client")
)

// Client is an HTTP proxy that accepts connections from local programs and
// proxies these via remote flashlight servers.
type Client struct {
	// Addr: listen address in form of host:port
	Addr string

	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	// MinQOS: (optional) the minimum QOS to require from proxies.
	MinQOS int

	priorCfg        *ClientConfig
	priorTrustedCAs *x509.CertPool
	cfgMutex        sync.RWMutex

	// Balanced CONNECT dialers.
	balChMu        sync.Mutex
	balCh          chan *balancer.Balancer
	balInitialized bool

	// Reverse HTTP proxies.
	rpChMu        sync.Mutex
	rpCh          chan *httputil.ReverseProxy
	rpInitialized bool

	hqfd fronted.Dialer
	l    net.Listener
}

// ListenAndServe makes the client listen for HTTP connections.  onListeningFn
// is a callback that gets invoked as soon as the server is accepting TCP
// connections.
func (client *Client) ListenAndServe(onListeningFn func()) (err error) {
	var l net.Listener

	// Attempting to bind a port on the given address.
	if l, err = net.Listen("tcp", client.Addr); err != nil {
		return fmt.Errorf("Client proxy was unable to listen at %s: %q", client.Addr, err)
	}

	// We opened the port successfully at this point, copying listener to our
	// client and executing the passed callback.
	client.l = l
	onListeningFn()

	// Creating an HTTP server.
	httpServer := &http.Server{
		ReadTimeout:  client.ReadTimeout,
		WriteTimeout: client.WriteTimeout,
		Handler:      client,
	}

	// Making the HTTP server we just created listen on the requested address
	// using the passed net.Listener.
	log.Debugf("About to start client (HTTP) proxy at %s", client.Addr)
	return httpServer.Serve(l)
}

// Configure updates the client's configuration.  Configure can be called
// before or after ListenAndServe, and can be called multiple times.  It
// returns the highest QOS fronted.Dialer available, or nil if none available.
func (client *Client) Configure(cfg *ClientConfig) fronted.Dialer {
	client.cfgMutex.Lock()
	defer client.cfgMutex.Unlock()

	log.Debug("Configure() called")
	// Checking if this is the first time the Configure method is called.
	if client.priorCfg != nil && client.priorTrustedCAs != nil {
		// This is not the first time, let's first test if there's any change to
		// apply.
		if reflect.DeepEqual(client.priorCfg, cfg) && reflect.DeepEqual(client.priorTrustedCAs, globals.TrustedCAs) {
			// Nothing to apply.
			log.Debugf("Client configuration unchanged")
			return client.hqfd
		}
		// Some stuff was changed, let's continue.
		log.Debugf("Client configuration changed")
	} else {
		// This is the first time we're configuring.
		log.Debugf("Client configuration initialized")
	}

	log.Debugf("Requiring minimum QOS of %d", cfg.MinQOS)
	client.MinQOS = cfg.MinQOS

	// Creating or updating balancer and getting highest QOS dialer.
	var bal *balancer.Balancer
	bal, client.hqfd = client.initBalancer(cfg)

	// Launching reverse proxy using the recently created balancer.
	client.initReverseProxy(bal, cfg.DumpHeaders)

	// Copying trusted CAs.
	client.priorCfg = cfg
	client.priorTrustedCAs = &x509.CertPool{}
	*client.priorTrustedCAs = *globals.TrustedCAs

	// Returning highest QOS dialer.
	return client.hqfd
}

// Stop is called when the client is no longer needed. It closes the
// client listener and underlying dialer connection pool
func (client *Client) Stop() error {
	client.hqfd.Close()
	return client.l.Close()
}
