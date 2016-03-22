package client

import (
	"time"

	"github.com/getlantern/fronted"
)

var (
	chainedDialTimeout = 30 * time.Second
)

// ClientConfig captures configuration information for a Client
type ClientConfig struct {
	// MinQOS: (optional) the minimum QOS to require from proxies.
	MinQOS int

	// Unique identifier for this device
	DeviceID string

	// List of CONNECT ports that are proxied via the remote proxy. Other ports
	// will be handled with direct connections.
	ProxiedCONNECTPorts []int

	DumpHeaders    bool // whether or not to dump headers of requests and responses
	ChainedServers map[string]*ChainedServerInfo
	OBFS4Servers   map[string]*OBFS4ServerInfo
	MasqueradeSets map[string][]*fronted.Masquerade
}
