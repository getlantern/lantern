package client

import (
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"reflect"
	"sync"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/golog"
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

	// ProxyAll: (optional)  poxy all sites regardless of being blocked or not
	ProxyAll bool

	// MinQOS: (optional) the minimum QOS to require from proxies.
	MinQOS int

	priorCfg *ClientConfig
	cfgMutex sync.RWMutex

	// Balanced CONNECT dialers.
	balCh          chan *balancer.Balancer
	balInitialized bool

	// Reverse HTTP proxies.
	rpCh          chan *httputil.ReverseProxy
	rpInitialized bool

	l net.Listener
}

// ListenAndServe makes the client listen for HTTP connections.  onListeningFn
// is a callback that gets invoked as soon as the server is accepting TCP
// connections.
func (client *Client) ListenAndServe(onListeningFn func()) error {
	var err error
	var l net.Listener

	if l, err = net.Listen("tcp", client.Addr); err != nil {
		return fmt.Errorf("Client proxy was unable to listen at %s: %q", client.Addr, err)
	}

	client.l = l
	onListeningFn()

	httpServer := &http.Server{
		ReadTimeout:  client.ReadTimeout,
		WriteTimeout: client.WriteTimeout,
		Handler:      client,
		ErrorLog:     log.AsStdLogger(),
	}

	log.Debugf("About to start client (HTTP) proxy at %s", client.Addr)

	return httpServer.Serve(l)
}

// Configure updates the client's configuration. Configure can be called
// before or after ListenAndServe, and can be called multiple times.  It
// returns the highest QOS fronted.Dialer available, or nil if none available.
func (client *Client) Configure(cfg *ClientConfig) {
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
	log.Debugf("Proxy all traffic or not: %v", cfg.ProxyAll)
	client.ProxyAll = cfg.ProxyAll

	client.initBalancer(cfg)

	client.priorCfg = cfg
}

// Stop is called when the client is no longer needed. It closes the
// client listener and underlying dialer connection pool
func (client *Client) Stop() error {
	return client.l.Close()
}
