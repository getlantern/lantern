package client

import (
	"log"

	"github.com/getlantern/balancer"
	"github.com/getlantern/flashlight/client"
)

type chainedServer struct {
	Addr      string
	Pipelined bool
	Cert      string
	AuthToken string
	Weight    int
	QOS       int
}

// Wraps a fronted.Dialer with a balancer.Dialer.
func (s *chainedServer) dialer() *balancer.Dialer {
	info := &client.ChainedServerInfo{
		Addr:      s.Addr,
		Cert:      s.Cert,
		AuthToken: s.AuthToken,
		Pipelined: s.Pipelined,
		QOS:       s.QOS,
		Weight:    s.Weight,
	}
	log.Printf("chained server address is %s", s.Addr)

	dialer, err := info.Dialer()
	if err != nil {
		log.Printf("Got error: %q", err)
		return nil
	}
	return dialer
}
