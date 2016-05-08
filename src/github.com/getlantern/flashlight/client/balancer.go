package client

import (
	"fmt"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/errlog"
)

// getBalancer waits for a message from client.balCh to arrive and then it
// writes it back to client.balCh before returning it as a value. This way we
// always have a balancer at client.balCh and, if we don't have one, it would
// block until one arrives.
func (client *Client) getBalancer() *balancer.Balancer {
	bal, ok := client.bal.Get(24 * time.Hour)
	if !ok {
		panic("No balancer!")
	}
	return bal.(*balancer.Balancer)
}

// initBalancer takes hosts from cfg.ChainedServers and it uses them to create a
// balancer.
func (client *Client) initBalancer(cfg *ClientConfig) (*balancer.Balancer, error) {
	if len(cfg.ChainedServers) == 0 {
		return nil, fmt.Errorf("No chained servers configured, not initializing balancer")
	}
	// The dialers slice must be large enough to handle all chained and obfs4
	// servers.
	dialers := make([]*balancer.Dialer, 0, len(cfg.ChainedServers))

	// Add chained (CONNECT proxy) servers.
	log.Debugf("Adding %d chained servers", len(cfg.ChainedServers))
	for _, s := range cfg.ChainedServers {
		dialer, err := s.Dialer(cfg.DeviceID)
		if err == nil {
			log.Debugf("Adding chained server: %v", s.Addr)
			dialers = append(dialers, dialer)
		} else {
			elog.Log(err, errlog.WithOp("configure"), errlog.WithProxy(&errlog.ProxyingInfo{
				ProxyType: errlog.ChainedProxy,
				ProxyAddr: s.Addr,
			}))
		}
	}

	bal := balancer.New(balancer.QualityFirst, dialers...)
	var oldBal *balancer.Balancer
	var ok bool
	ob, ok := client.bal.Get(0 * time.Millisecond)
	if ok {
		oldBal = ob.(*balancer.Balancer)
	}

	log.Trace("Publishing balancer")
	client.bal.Set(bal)

	if oldBal != nil {
		// Close old balancer on a goroutine to avoid blocking here
		go func() {
			oldBal.Close()
			log.Debug("Closed old balancer")
		}()
	}

	return bal, nil
}
