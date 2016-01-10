package client

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/chained"
	"github.com/getlantern/flashlight/client/stats"
	"github.com/getlantern/golog"
	"github.com/getlantern/idletiming"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"

	"github.com/getlantern/flashlight/settings"
)

// Close connections idle for a period to avoid dangling connections.
// 1 hour is long enough to avoid interrupt normal connections but short enough
// to eliminate "too many open files" error.
var (
	idleTimeout        = 1 * time.Hour
	chainedDialTimeout = 30 * time.Second
	log                = golog.LoggerFor("flashlight.client.chained")
)

// ChainedServerInfo provides identity information for a chained server.
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

	// Trusted: Determines if a host can be trusted with plain HTTP traffic.
	Trusted bool
}

// Dialer creates a *balancer.Dialer backed by a chained server.
func (s *ChainedServerInfo) Dialer() (*balancer.Dialer, error) {
	netd := &net.Dialer{Timeout: chainedDialTimeout}

	var dial func() (net.Conn, error)
	if s.Cert == "" {
		log.Error("No Cert configured for chained server, will dial with plain tcp")
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
				if err := conn.Close(); err != nil {
					log.Debugf("Error closing chained server connection: %s", err)
				}
				return nil, fmt.Errorf("Server's certificate didn't match expected!")
			}
			return conn, err
		}
	}

	// Is this a trusted proxy that we could use for HTTP traffic?
	var trusted string
	if s.Trusted {
		trusted = "(trusted) "
	}
	label := fmt.Sprintf("%schained proxy at %s", trusted, s.Addr)

	ccfg := chained.Config{
		DialServer: dial,
		Label:      label,
	}

	ccfg.OnRequest = func(req *http.Request) {
		if s.AuthToken != "" {
			req.Header.Set("X-LANTERN-AUTH-TOKEN", s.AuthToken)
		}
		req.Header.Set("X-LANTERN-DEVICE-ID", settings.GetInstanceID())
	}
	d := chained.NewDialer(ccfg)

	return &balancer.Dialer{
		Label:   label,
		Weight:  s.Weight,
		QOS:     s.QOS,
		Trusted: s.Trusted,
		Dial: func(network, addr string) (conn net.Conn, err error) {
			conn, err = d.Dial(network, addr)
			if err != nil {
				return conn, err
			}
			conn = idletiming.Conn(conn, idleTimeout, func() {
				log.Debugf("Proxy connection to %s via %s idle for %v, closing", addr, conn.RemoteAddr(), idleTimeout)
				if err := conn.Close(); err != nil {
					log.Debugf("Unable to close connection: %v", err)
				}
			})
			return stats.WithStats(conn, err)
		},
		AuthToken: s.AuthToken,
	}, nil
}
