package client

import (
	"fmt"
	"net"

	"github.com/getlantern/balancer"

	"github.com/Yawning/obfs4/transports/obfs4"

	"git.torproject.org/pluggable-transports/goptlib.git"
)

// OBFS4ServerInfo provides identity information for an obfs4 chained server.
type OBFS4ServerInfo struct {
	ChainedServerInfo

	// IATMode
	IATMode string
}

// Dialer creates a *balancer.Dialer backed by an OBFS4 server.
func (s *OBFS4ServerInfo) Dialer(deviceID string) (*balancer.Dialer, error) {
	var dial func() (net.Conn, error)
	if s.Cert == "" {
		return nil, fmt.Errorf("No Cert configured for obfs4 server, will dial with plain tcp")
	}

	tr := obfs4.Transport{}
	cf, err := tr.ClientFactory("")
	if err != nil {
		return nil, fmt.Errorf("Unable to create obfs4 client factory: %v", err)
	}

	ptArgs := &pt.Args{}
	ptArgs.Add("cert", s.Cert)
	ptArgs.Add("iat-mode", s.IATMode)

	args, err := cf.ParseArgs(ptArgs)
	if err != nil {
		return nil, fmt.Errorf("Unable to parse client args: %v", err)
	}

	dial = func() (net.Conn, error) {
		return cf.Dial("tcp", s.Addr, net.Dial, args)
	}

	return chainedDialer(&s.ChainedServerInfo, deviceID, dial)
}
