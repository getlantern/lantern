package client

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"

	"github.com/getlantern/balancer"
	"github.com/getlantern/chained"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
)

type ChainedServerInfo struct {
	// Addr: the host:port of the upstream proxy server
	Addr string

	// Pipelined: If true, requests to the chained server will be pipelined
	Pipelined bool

	// Cert: optional PEM encoded certificate for the server. If specified,
	// server will be dialed using TLS over tcp. Otherwise, server will be
	// dialed using plain tcp.
	Cert string

	// AuthToken: the authtoken to present to the upstream server.
	AuthToken string

	// Weight: relative weight versus other servers (for round-robin)
	Weight int

	// QOS: relative quality of service offered. Should be >= 0, with higher
	// values indicating higher QOS.
	QOS int
}

func (s *ChainedServerInfo) Dialer() (*balancer.Dialer, error) {
	log.Debug("Building dialer")

	netd := &net.Dialer{
		Timeout: chainedDialTimeout,
	}

	var dial func() (net.Conn, error)
	if s.Cert == "" {
		log.Trace("No Cert configured for chained server, will dial with plain tcp")
		dial = func() (net.Conn, error) {
			return netd.Dial("tcp", s.Addr)
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
			conn, err := tlsdialer.DialWithDialer(netd, "tcp", s.Addr, false, &tls.Config{
				ClientSessionCache: sessionCache,
				InsecureSkipVerify: true,
			})
			if err != nil {
				return nil, err
			}
			if !conn.ConnectionState().PeerCertificates[0].Equal(x509cert) {
				conn.Close()
				return nil, fmt.Errorf("Server's certificate didn't match expected!")
			}
			return conn, err
		}
	}

	ccfg := chained.Config{
		DialServer: dial,
	}
	if s.AuthToken != "" {
		ccfg.OnRequest = func(req *http.Request) {
			req.Header.Set("X-LANTERN-AUTH-TOKEN", s.AuthToken)
		}
	}
	d := chained.NewDialer(ccfg)

	return &balancer.Dialer{
		Label:  fmt.Sprintf("chained proxy at %s", s.Addr),
		Weight: s.Weight,
		QOS:    s.QOS,
		Dial: func(network, addr string) (net.Conn, error) {
			return withStats(d.Dial(network, addr))
		},
	}, nil
}
