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
	"github.com/getlantern/flashlight/autoupdate"
	clientconfig "github.com/getlantern/flashlight/client/config"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/pac"
	"github.com/getlantern/flashlight/proxiedsites"
	"github.com/getlantern/flashlight/settings"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
)

var (
	log      = golog.LoggerFor("flashlight.client")
	cfgMutex sync.Mutex

	Version      string
	RevisionDate string
	LogglyToken  string
	LogglyTag    string
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

	priorCfg *clientconfig.ClientConfig
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

func (client *Client) ApplyClientConfig(cfg *config.Config) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	certs, err := cfg.GetTrustedCACerts()
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configure fronted: %s", err)
	} else {
		fronted.Configure(certs, cfg.Client.MasqueradeSets)
	}

	autoupdate.Configure(cfg)
	logging.Configure(cfg.Addr, cfg.CloudConfigCA, settings.GetInstanceID(), Version, RevisionDate)
	proxiedsites.Configure(cfg.ProxiedSites)
	log.Debugf("Proxy all traffic or not: %v", settings.GetProxyAll())
	pac.ServeProxyAllPacFile(settings.GetProxyAll())
	// Note - we deliberately ignore the error from statreporter.Configure here
	_ = statreporter.Configure(cfg.Stats, settings.GetInstanceID())

	// Update client configuration and get the highest QOS dialer available.
	client.Configure(cfg.Client)

	// We offload this onto a go routine because creating the http clients
	// blocks on waiting for the local server, and the local server starts
	// later on this same thread, so it would otherwise creating a deadlock.
	go func() {
		withHttpClient(cfg.Addr, statserver.Configure)
	}()
}

func withHttpClient(addr string, withClient func(client *http.Client)) {
	if httpClient, err := util.HTTPClient("", addr); err != nil {
		log.Errorf("Could not create HTTP client via %s: %s", addr, err)
	} else {
		withClient(httpClient)
	}
}

// Configure updates the client's configuration. Configure can be called
// before or after ListenAndServe, and can be called multiple times.  It
// returns the highest QOS fronted.Dialer available, or nil if none available.
func (client *Client) Configure(cfg *clientconfig.ClientConfig) {
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
	log.Debugf("Proxy all traffic or not: %v", settings.GetProxyAll())
	client.ProxyAll = settings.GetProxyAll()

	client.initBalancer(cfg)

	client.priorCfg = cfg
}

// Stop is called when the client is no longer needed. It closes the
// client listener and underlying dialer connection pool
func (client *Client) Stop() error {

	bal := client.GetBalancer()
	if bal != nil {
		bal.Close()
	}
	return client.l.Close()
}
