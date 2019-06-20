package client

import (
	"time"

	"github.com/getlantern/fronted"
)

var (
	chainedDialTimeout = 10 * time.Second
)

// ClientConfig captures configuration information for a Client
type ClientConfig struct {
	// MinQOS: (optional) the minimum QOS to require from proxies.
	MinQOS int

	// List of CONNECT ports that are proxied via the remote proxy. Other ports
	// will be handled with direct connections.
	ProxiedCONNECTPorts []int

	DumpHeaders    bool // whether or not to dump headers of requests and responses
	ChainedServers map[string]*ChainedServerInfo
	MasqueradeSets map[string][]*fronted.Masquerade
}
