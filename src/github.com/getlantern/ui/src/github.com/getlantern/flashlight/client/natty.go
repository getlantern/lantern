package client

import (
	"net"
	"runtime"
	"time"

	"github.com/getlantern/deepcopy"
	"github.com/getlantern/nattywad"
	"github.com/getlantern/waddell"

	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/nattest"
	"github.com/getlantern/flashlight/statreporter"
)

const (
	HighQOS = 10
)

var (
	// idleTimeout needs to be small enough that we stop using connections
	// before the upstream server/CDN closes them itself.
	// TODO: make this configurable.
	idleTimeout = 10 * time.Second
)

func (client *Client) initNatty(cfg *ClientConfig) {
	if client.nattywadClient == nil {
		client.nattywadClient = &nattywad.Client{
			ClientMgr: &waddell.ClientMgr{
				Dial: func(addr string) (net.Conn, error) {
					// Clients always connect to waddell via a proxy to prevent the
					// waddell connection from being blocked by censors.
					return client.getBalancer().DialQOS("tcp", addr, HighQOS)
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

	// Convert peers to slice
	peers := make([]*nattywad.ServerPeer, 0, len(cfg.Peers))
	for _, peer := range cfg.Peers {
		peers = append(peers, peer)
	}
	go client.nattywadClient.Configure(peers)

	// Remember cfg for comparing later
	client.priorCfg = &ClientConfig{}
	deepcopy.Copy(client.priorCfg, cfg)
	client.priorTrustedCAs = globals.TrustedCAs
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
