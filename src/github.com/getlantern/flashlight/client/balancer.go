package client

import (
	"fmt"

	"github.com/getlantern/balancer"
)

var bal = balancer.New(balancer.QualityFirst)

// initBalancer takes hosts from cfg.ChainedServers and it uses them to create a
// balancer.
func (client *Client) initBalancer(proxies map[string]*ChainedServerInfo, deviceID string) error {
	if len(proxies) == 0 {
		return fmt.Errorf("No chained servers configured, not initializing balancer")
	}
	// The dialers slice must be large enough to handle all chained and obfs4
	// servers.
	dialers := make([]*balancer.Dialer, 0, len(proxies))

	// Add chained (CONNECT proxy) servers.
	log.Debugf("Adding %d chained servers", len(proxies))
	for _, s := range proxies {
		dialer, err := ChainedDialer(s, deviceID)
		if err != nil {
			log.Errorf("Unable to configure chained server. Received error: %v", err)
			continue
		}
		log.Debugf("Adding chained server: %v", s.Addr)
		dialers = append(dialers, dialer)
	}

	bal.Reset(dialers...)
	return nil
}
