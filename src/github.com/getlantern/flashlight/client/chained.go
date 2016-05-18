package client

import (
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync/atomic"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/chained"
	"github.com/getlantern/idletiming"
	"github.com/getlantern/withtimeout"
)

// Close connections idle for a period to avoid dangling connections.
// 1 hour is long enough to avoid interrupt normal connections but short enough
// to eliminate "too many open files" error.
var idleTimeout = 1 * time.Hour

// Lantern internal sites won't be used as check target.
var internalSiteSuffix = "getiantem.org"

// ForceChainedProxyAddr - If specified, all proxying will go through this address
var ForceChainedProxyAddr string

// ForceAuthToken - If specified, auth token will be forced to this
var ForceAuthToken string

// ChainedServerInfo contains all the data for connecting to a given chained
// server.
type ChainedServerInfo struct {
	// Addr: the host:port of the upstream proxy server
	Addr string

	// Cert: optional PEM encoded certificate for the server. If specified,
	// server will be dialed using TLS over tcp. Otherwise, server will be
	// dialed using plain tcp. For OBFS4 proxies, this is the Base64-encoded obfs4
	// certificate.
	Cert string

	// AuthToken: the authtoken to present to the upstream server.
	AuthToken string

	// Trusted: Determines if a host can be trusted with plain HTTP traffic.
	Trusted bool

	// PluggableTransport: If specified, a pluggable transport will be used
	PluggableTransport string

	// PluggableTransportSettings: Settings for pluggable transport
	PluggableTransportSettings map[string]string

	//  the host:port used to check this server. It's set as the last dialed
	//  host if the port is 80, except those with internalSiteSuffix.
	checkTarget atomic.Value
}

// Dialer creates a *balancer.Dialer backed by a chained server.
func (s *ChainedServerInfo) Dialer(deviceID string) (*balancer.Dialer, error) {
	if s.PluggableTransport != "" {
		log.Debugf("Using pluggable transport %v for server at %v", s.PluggableTransport, s.Addr)
	}

	dialFactory := pluggableTransports[s.PluggableTransport]
	if dialFactory == nil {
		return nil, fmt.Errorf("No dial factory defined for transport: %v", s.PluggableTransport)
	}
	dial, err := dialFactory(s, deviceID)
	if err != nil {
		return nil, fmt.Errorf("Unable to construct dialFN: %v", err)
	}

	// Is this a trusted proxy that we could use for HTTP traffic?
	var trusted string
	if s.Trusted {
		trusted = "(trusted) "
	}
	label := fmt.Sprintf("%schained proxy at %s [%v]", trusted, s.Addr, s.PluggableTransport)

	ccfg := chained.Config{
		DialServer: dial,
		Label:      label,
		OnRequest: func(req *http.Request) {
			s.attachHeaders(req, deviceID)
		},
	}
	d := chained.NewDialer(ccfg)

	return &balancer.Dialer{
		Label:   label,
		Trusted: s.Trusted,
		DialFN: func(network, addr string) (net.Conn, error) {
			conn, err := d(network, addr)
			if err != nil {
				return nil, err
			}

			s.updateCheckTarget(addr)
			conn = idletiming.Conn(conn, idleTimeout, func() {
				log.Debugf("Proxy connection to %s via %s idle for %v, closing", addr, conn.RemoteAddr(), idleTimeout)
				if err := conn.Close(); err != nil {
					log.Debugf("Unable to close connection: %v", err)
				}
			})

			return conn, nil
		},
		Check: func() bool {
			return s.check(d, deviceID)
		},
		OnRequest: ccfg.OnRequest,
	}, nil
}

func (s *ChainedServerInfo) attachHeaders(req *http.Request, deviceID string) {
	authToken := s.AuthToken
	if ForceAuthToken != "" {
		authToken = ForceAuthToken
	}
	if authToken != "" {
		req.Header.Add("X-LANTERN-AUTH-TOKEN", authToken)
	}
	req.Header.Set("X-LANTERN-DEVICE-ID", deviceID)
}

func (s *ChainedServerInfo) updateCheckTarget(addr string) {
	host, port, e := net.SplitHostPort(addr)
	if e != nil {
		log.Errorf("failed to split port from %s", addr)
		return
	}
	if strings.HasSuffix(host, internalSiteSuffix) || port != "80" {
		log.Tracef("Skip setting %s as check target", addr)
		return
	}
	s.checkTarget.Store(addr)
}

func (s *ChainedServerInfo) check(dial func(string, string) (net.Conn, error), deviceID string) bool {
	rt := &http.Transport{
		DisableKeepAlives: true,
		Dial:              dial,
	}
	var url string
	checkTarget, isSet := s.checkTarget.Load().(string)
	if !isSet {
		url = "http://ping-chained-server"
	} else {
		url = fmt.Sprintf("http://%s/index.html", checkTarget)
	}
	req, err := http.NewRequest("HEAD", url, nil)
	if err != nil {
		log.Errorf("Could not create HTTP request: %v", err)
		return false
	}
	if !isSet {
		req.Header.Set("X-Lantern-Ping", "small")
	}

	s.attachHeaders(req, deviceID)
	ok, timedOut, _ := withtimeout.Do(60*time.Second, func() (interface{}, error) {
		resp, err := rt.RoundTrip(req)
		if err != nil {
			log.Debugf("Error testing dialer %s to %s: %s", s.Addr, url, err)
			return false, nil
		}
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
		good := resp.StatusCode < 500
		msg := fmt.Sprintf("HEAD %s through chained server at %s, status code %d", url, s.Addr, resp.StatusCode)
		if !good {
			log.Debug(msg)
		} else {
			log.Trace(msg)
		}
		return good, nil
	})
	if timedOut {
		log.Errorf("Timed out checking dialer at: %v", s.Addr)
	}
	return !timedOut && ok.(bool)
}
