package client

import (
	"crypto/x509"
	"math/rand"
	"net"
	"net/http"
	"reflect"
	"runtime"
	"strconv"
	"sync"
	"time"

	"github.com/getlantern/deepcopy"
	"github.com/getlantern/enproxy"
	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/nattest"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/golog"
	"github.com/getlantern/nattywad"
	"github.com/getlantern/waddell"
)

const (
	CONNECT = "CONNECT" // HTTP CONNECT method

	REVERSE_PROXY_FLUSH_INTERVAL = 250 * time.Millisecond

	X_FLASHLIGHT_QOS = "X-Flashlight-QOS"

	HighQOS = 10

	// Cutoff for logging warnings about a dial having taken a long time.
	longDialLimit = 10 * time.Second

	// idleTimeout needs to be small enough that we stop using connections
	// before the upstream server/CDN closes them itself.
	// TODO: make this configurable.
	idleTimeout = 10 * time.Second
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

	priorCfg           *ClientConfig
	priorTrustedCAs    *x509.CertPool
	cfgMutex           sync.RWMutex
	servers            []*server
	totalServerWeights int
	nattywadClient     *nattywad.Client
	verifiedSets       map[string]*verifiedMasqueradeSet
}

// ListenAndServe makes the client listen for HTTP connections
func (client *Client) ListenAndServe() error {
	httpServer := &http.Server{
		Addr:         client.Addr,
		ReadTimeout:  client.ReadTimeout,
		WriteTimeout: client.WriteTimeout,
		Handler:      client,
	}

	log.Debugf("About to start client (http) proxy at %s", client.Addr)
	return httpServer.ListenAndServe()
}

// Configure updates the client's configuration.  Configure can be called
// before or after ListenAndServe, and can be called multiple times.  The
// optional enproxyConfigs parameter allows explicitly specifying enproxy
// configurations for the servers in ClientConfig in lieu of building them based
// on the ServerInfo in ClientConfig (mostly useful for testing).
func (client *Client) Configure(cfg *ClientConfig, enproxyConfigs []*enproxy.Config) {
	client.cfgMutex.Lock()
	defer client.cfgMutex.Unlock()

	log.Debug("Configure() called")
	if client.priorCfg != nil && client.priorTrustedCAs != nil {
		if reflect.DeepEqual(client.priorCfg, cfg) &&
			reflect.DeepEqual(client.priorTrustedCAs, globals.TrustedCAs) {
			log.Debugf("Client configuration unchanged")
			return
		} else {
			log.Debugf("Client configuration changed")
		}
	} else {
		log.Debugf("Client configuration initialized")
	}

	// Make a copy of cfg for comparing later
	client.priorCfg = &ClientConfig{}
	deepcopy.Copy(client.priorCfg, cfg)
	client.priorTrustedCAs = globals.TrustedCAs

	if client.verifiedSets != nil {
		// Stop old verifications
		for _, verifiedSet := range client.verifiedSets {
			go verifiedSet.stop()
		}
	}

	// Set up new verified masquerade sets
	client.verifiedSets = make(map[string]*verifiedMasqueradeSet)

	for key, masqueradeSet := range cfg.MasqueradeSets {
		testServer := cfg.highestQosServer(key)
		if testServer != nil {
			client.verifiedSets[key] = newVerifiedMasqueradeSet(testServer, masqueradeSet)
		}
	}

	// Close existing servers
	if client.servers != nil {
		for _, server := range client.servers {
			server.close()
		}
	}

	// Configure servers
	client.servers = make([]*server, len(cfg.Servers))
	i := 0
	for _, serverInfo := range cfg.Servers {
		var enproxyConfig *enproxy.Config
		if enproxyConfigs != nil {
			enproxyConfig = enproxyConfigs[i]
		}
		client.servers[i] = serverInfo.buildServer(
			cfg.DumpHeaders,
			client.verifiedSets[serverInfo.MasqueradeSet],
			enproxyConfig)
		i = i + 1
	}

	// Calculate total server weights
	client.totalServerWeights = 0
	for _, server := range client.servers {
		client.totalServerWeights = client.totalServerWeights + server.info.Weight
	}

	if client.nattywadClient == nil {
		client.nattywadClient = &nattywad.Client{
			ClientMgr: &waddell.ClientMgr{
				Dial: func(addr string) (net.Conn, error) {
					// Clients always connect to waddell via a proxy to prevent the
					// waddell connection from being blocked by censors.
					server := client.randomServerForQOS(HighQOS)
					return server.dialWithEnproxy("tcp", addr)
				},
				ServerCert: globals.WaddellCert,
			},
			OnSuccess: func(info *nattywad.TraversalInfo) {
				log.Debugf("NAT traversal Succeeded: %s", info)
				log.Tracef("Peer Country: %s", info.Peer.Extras["country"])
				serverConnected := nattest.Ping(info.LocalAddr, info.RemoteAddr)
				reportTraversalResult(info, true, serverConnected)
			},
			OnFailure: func(info *nattywad.TraversalInfo) {
				log.Debugf("NAT traversal Failed: %s", info)
				log.Tracef("Peer Country: %s", info.Peer.Extras["country"])
				reportTraversalResult(info, false, false)
			},
			KeepAliveInterval: idleTimeout - 2*time.Second,
		}
	}

	peers := make([]*nattywad.ServerPeer, len(cfg.Peers))
	i = 0
	for _, peer := range cfg.Peers {
		peers[i] = peer
		i = i + 1
	}
	go client.nattywadClient.Configure(peers)
}

// highestQos finds the server with the highest reported quality of service for
// the named masqueradeSet.
func (cfg *ClientConfig) highestQosServer(masqueradeSet string) *ServerInfo {
	highest := 0
	var info *ServerInfo
	for _, serverInfo := range cfg.Servers {
		if serverInfo.MasqueradeSet == masqueradeSet && serverInfo.QOS > highest {
			highest = serverInfo.QOS
			info = serverInfo
		}
	}
	return info
}

// ServeHTTP implements the method from interface http.Handler
func (client *Client) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	server := client.randomServer(req)
	log.Tracef("Using server %s to handle request for %s", server.info.Host, req.RequestURI)
	if req.Method == CONNECT {
		server.enproxyConfig.Intercept(resp, req)
	} else {
		server.reverseProxy.ServeHTTP(resp, req)
	}
}

// randomServer picks a random server from the list of servers, with higher
// weight servers more likely to be picked.  If the request includes our
// custom QOS header, only servers whose QOS meets or exceeds the requested
// value are considered for inclusion.  However, if no servers meet the QOS
// requirement, the last server in the list will be used by default.
func (client *Client) randomServer(req *http.Request) *server {
	return client.randomServerForQOS(targetQOS(req))
}

func (client *Client) randomServerForQOS(targetQOS int) *server {
	servers, totalServerWeights := client.getServers()

	// Pick a random server using a target value between 0 and the total server weights
	t := rand.Intn(totalServerWeights)
	aw := 0
	for i, server := range servers {
		if i == len(servers)-1 {
			// Last server, use it irrespective of target QOS
			return server
		}
		aw = aw + server.info.Weight
		if server.info.QOS < targetQOS {
			// QOS too low, exclude server from rotation
			t = t + server.info.Weight
			continue
		}
		if aw > t {
			// We've reached our random target value, use this server
			return server
		}
	}

	// We should never reach this
	panic("No server found!")
}

// targetQOS determines the target quality of service given the X-Flashlight-QOS
// header if available, else returns 0.
func targetQOS(req *http.Request) int {
	requestedQOS := req.Header.Get(X_FLASHLIGHT_QOS)
	if requestedQOS != "" {
		rqos, err := strconv.Atoi(requestedQOS)
		if err == nil {
			return rqos
		}
	}

	return 0
}

func (client *Client) getServers() ([]*server, int) {
	client.cfgMutex.RLock()
	defer client.cfgMutex.RUnlock()
	return client.servers, client.totalServerWeights
}

func reportTraversalResult(info *nattywad.TraversalInfo, clientGotFiveTuple bool, connectionSucceeded bool) {
	answererCountry := "xx"
	if _, ok := info.Peer.Extras["country"]; ok {
		answererCountry = info.Peer.Extras["country"].(string)
	}

	dims := statreporter.CountryDim().
		And("answerercountry", answererCountry).
		And("offereranswerercountries", globals.Country+"_"+answererCountry).
		And("operatingsystem", runtime.GOOS)

	dims.Increment("traversalAttempted").Add(1)

	if info.ServerRespondedToSignaling {
		dims.Increment("answererOnline").Add(1)
	}
	if info.ServerGotFiveTuple {
		dims.Increment("answererGot5Tuple").Add(1)
	}
	if clientGotFiveTuple {
		dims.Increment("offererGot5Tuple").Add(1)
	}
	if info.ServerGotFiveTuple && clientGotFiveTuple {
		dims.Increment("traversalSucceeded").Add(1)
		dims.Increment("durationOfSuccessfulTraversal").Add(int64(info.Duration.Seconds()))
	}
	if connectionSucceeded {
		dims.Increment("connectionSucceeded").Add(1)
	}
}
