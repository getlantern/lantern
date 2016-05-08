package client

import (
	"crypto/tls"
	"fmt"
	"net"

	"github.com/Yawning/obfs4/transports/obfs4"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"

	"git.torproject.org/pluggable-transports/goptlib.git"
)

type dialFN func() (net.Conn, error)
type dialFactory func(*ChainedServerInfo, string) (dialFN, error)

var pluggableTransports = map[string]dialFactory{
	"":      defaultDialFactory,
	"obfs4": obfs4DialFactory,
}

func defaultDialFactory(s *ChainedServerInfo, deviceID string) (dialFN, error) {
	netd := &net.Dialer{Timeout: chainedDialTimeout}
	forceProxy := ForceChainedProxyAddr != ""
	addr := s.Addr
	if forceProxy {
		log.Debugf("Forcing proxying to server at %v instead of configured server at %v", ForceChainedProxyAddr, s.Addr)
		addr = ForceChainedProxyAddr
	}

	var dial dialFN

	if s.Cert == "" && !forceProxy {
		elog.Log(fmt.Errorf("No Cert configured for chained server, will dial with plain tcp"))
		dial = func() (net.Conn, error) {
			return netd.Dial("tcp", addr)
		}
	} else {
		log.Trace("Cert configured for chained server, will dial with tls over tcp")
		cert, err := keyman.LoadCertificateFromPEMBytes([]byte(s.Cert))
		if err != nil {
			return nil, fmt.Errorf("Unable to parse certificate: %s", err)
		}
		x509cert := cert.X509()
		sessionCache := tls.NewLRUClientSessionCache(1000)
		dial = func() (net.Conn, error) {
			conn, err := tlsdialer.DialWithDialer(netd, "tcp", addr, false, &tls.Config{
				ClientSessionCache: sessionCache,
				InsecureSkipVerify: true,
			})
			if err != nil {
				return nil, err
			}
			if !forceProxy && !conn.ConnectionState().PeerCertificates[0].Equal(x509cert) {
				if err := conn.Close(); err != nil {
					log.Debugf("Error closing chained server connection: %s", err)
				}
				return nil, fmt.Errorf("Server's certificate didn't match expected!")
			}
			return conn, err
		}
	}

	return dial, nil
}

func obfs4DialFactory(s *ChainedServerInfo, deviceID string) (dialFN, error) {
	if s.Cert == "" {
		return nil, fmt.Errorf("No Cert configured for obfs4 server, can't connect")
	}

	tr := obfs4.Transport{}
	cf, err := tr.ClientFactory("")
	if err != nil {
		return nil, fmt.Errorf("Unable to create obfs4 client factory: %v", err)
	}

	ptArgs := &pt.Args{}
	ptArgs.Add("cert", s.Cert)
	ptArgs.Add("iat-mode", s.PluggableTransportSettings["iat-mode"])

	args, err := cf.ParseArgs(ptArgs)
	if err != nil {
		return nil, fmt.Errorf("Unable to parse client args: %v", err)
	}

	return func() (net.Conn, error) {
		return cf.Dial("tcp", s.Addr, net.Dial, args)
	}, nil
}
