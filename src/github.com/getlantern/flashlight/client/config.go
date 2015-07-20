package client

import (
	"sort"
	"time"

	"github.com/getlantern/fronted"
)

var (
	chainedDialTimeout = 30 * time.Second
)

// ClientConfig captures configuration information for a Client
type ClientConfig struct {
	MinQOS         int
	DumpHeaders    bool // whether or not to dump headers of requests and responses
	ProxyAll       bool // Proxy all sites regardless of being blocked or not
	FrontedServers []*FrontedServerInfo
	ChainedServers map[string]*ChainedServerInfo
	MasqueradeSets map[string][]*fronted.Masquerade
}

// SortServers sorts the Servers array in place, ordered by host
func (c *ClientConfig) SortServers() {
	sort.Sort(ByHost(c.FrontedServers))
}

// ByHost implements sort.Interface for []*ServerInfo based on the host
type ByHost []*FrontedServerInfo

func (a ByHost) Len() int           { return len(a) }
func (a ByHost) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByHost) Less(i, j int) bool { return a[i].Host < a[j].Host }
