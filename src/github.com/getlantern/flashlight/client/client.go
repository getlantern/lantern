package client

import (
	"math/rand"
	"net/http"
	"reflect"
	"strconv"
	"sync"
	"time"

	"github.com/getlantern/enproxy"
	"github.com/getlantern/flashlight/log"
)

const (
	CONNECT = "CONNECT" // HTTP CONNECT method

	REVERSE_PROXY_FLUSH_INTERVAL = 250 * time.Millisecond

	X_FLASHLIGHT_QOS = "X-Flashlight-QOS"
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

	cfg                *ClientConfig
	cfgMutex           sync.RWMutex
	servers            []*server
	totalServerWeights int
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
	if client.cfg != nil {
		if reflect.DeepEqual(client.cfg, cfg) {
			log.Debugf("Client configuration unchanged")
			return
		} else {
			log.Debugf("Client configuration changed")
		}
	} else {
		log.Debugf("Client configuration initialized")
	}

	client.cfg = cfg

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
	log.Debugf("Using server %s to handle request for %s", server.info.Host, req.RequestURI)
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
	targetQOS := client.targetQOS(req)

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
func (client *Client) targetQOS(req *http.Request) int {
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
