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
	balCh           chan *balancer.Balancer
	balInitialized  bool
	rpCh            chan *httputil.ReverseProxy
	rpInitialized   bool
	hqfd            fronted.Dialer
}

// ListenAndServe makes the client listen for HTTP connections.
// onListening is a callback that gets invoked as soon as the server is
// accepting TCP connections.
func (client *Client) ListenAndServe(onListening func()) error {
	l, err := net.Listen("tcp", client.Addr)
	if err != nil {
		return fmt.Errorf("Client unable to listen at %v: %v", client.Addr, err)
	}

	onListening()

	httpServer := &http.Server{
		ReadTimeout:  client.ReadTimeout,
		WriteTimeout: client.WriteTimeout,
		Handler:      client,
	}

	log.Debugf("About to start client (http) proxy at %s", client.Addr)
	return httpServer.Serve(l)
}

// Configure updates the client's configuration.  Configure can be called
// before or after ListenAndServe, and can be called multiple times.
// It returns the highest QOS fronted.Dialer available, or nil if none
// available.
func (client *Client) Configure(cfg *ClientConfig) fronted.Dialer {
	client.cfgMutex.Lock()
	defer client.cfgMutex.Unlock()

	log.Debug("Configure() called")
	if client.priorCfg != nil && client.priorTrustedCAs != nil {
		if reflect.DeepEqual(client.priorCfg, cfg) &&
			reflect.DeepEqual(client.priorTrustedCAs, globals.TrustedCAs) {
			log.Debugf("Client configuration unchanged")
			return client.hqfd
		} else {
			log.Debugf("Client configuration changed")
		}
	} else {
		log.Debugf("Client configuration initialized")
	}

	log.Debugf("Requiring minimum QOS of %d", cfg.MinQOS)
	client.MinQOS = cfg.MinQOS
	var bal *balancer.Balancer
	bal, client.hqfd = client.initBalancer(cfg)
	client.initReverseProxy(bal, cfg.DumpHeaders)
	client.priorCfg = cfg
	client.priorTrustedCAs = &x509.CertPool{}
	*client.priorTrustedCAs = *globals.TrustedCAs

	return client.hqfd
}
