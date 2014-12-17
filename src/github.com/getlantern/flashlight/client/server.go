package client

import (
	"crypto/tls"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"time"

	"github.com/getlantern/connpool"
	"github.com/getlantern/enproxy"
	"github.com/getlantern/flashlight/log"
	"github.com/getlantern/flashlight/proxy"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/keyman"
	"net/http/httputil"

	"gopkg.in/getlantern/tlsdialer.v2"
)

var (
	// Cutoff for logging warnings about a dial having taken a long time.
	longDialLimit = 10 * time.Second

	// idleTimeout needs to be small enough that we stop using connections
	// before the upstream server/CDN closes them itself.
	// TODO: make this configurable.
	idleTimeout = 10 * time.Second
)

type server struct {
	info          *ServerInfo
	masquerades   *verifiedMasqueradeSet
	enproxyConfig *enproxy.Config
	connPool      *connpool.Pool
	reverseProxy  *httputil.ReverseProxy
}

// buildReverseProxy builds the httputil.ReverseProxy used to proxy requests to
// the server.
func (server *server) buildReverseProxy(shouldDumpHeaders bool) *httputil.ReverseProxy {
	return &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			// do nothing
		},
		Transport: withDumpHeaders(
			shouldDumpHeaders,
			&http.Transport{
				// We disable keepalives because some servers pretend to support
				// keep-alives but close their connections immediately, which
				// causes an error inside ReverseProxy.  This is not an issue
				// for HTTPS because  the browser is responsible for handling
				// the problem, which browsers like Chrome and Firefox already
				// know to do.
				// See https://code.google.com/p/go/issues/detail?id=4677
				DisableKeepAlives: true,
				Dial:              server.dialWithEnproxy,
			}),
		// Set a FlushInterval to prevent overly aggressive buffering of
		// responses, which helps keep memory usage down
		FlushInterval: 250 * time.Millisecond,
	}
}

func (server *server) dialWithEnproxy(network, addr string) (net.Conn, error) {
	conn := &enproxy.Conn{
		Addr:   addr,
		Config: server.enproxyConfig,
	}
	err := conn.Connect()
	if err != nil {
		return nil, err
	}
	return conn, nil
}

func (server *server) buildEnproxyConfig() *enproxy.Config {
	server.connPool = &connpool.Pool{
		MinSize:      30,
		ClaimTimeout: idleTimeout,
		Dial:         server.info.dialerFor(server.nextMasquerade),
	}
	server.connPool.Start()

	return server.info.enproxyConfigWith(func(addr string) (net.Conn, error) {
		return server.connPool.Get()
	})
}

func (server *server) close() {
	if server.connPool != nil {
		// We stop the connPool on a goroutine so as not to wait for Stop to finish
		go server.connPool.Stop()
	}
}

func (server *server) nextMasquerade() *Masquerade {
	if server.masquerades == nil {
		return nil
	}
	masquerade := server.masquerades.nextVerified()
	return masquerade
}

// withDumpHeaders creates a RoundTripper that uses the supplied RoundTripper
// and that dumps headers is client is so configured.
func withDumpHeaders(shouldDumpHeaders bool, rt http.RoundTripper) http.RoundTripper {
	if !shouldDumpHeaders {
		return rt
	}
	return &headerDumpingRoundTripper{rt}
}

// headerDumpingRoundTripper is an http.RoundTripper that wraps another
// http.RoundTripper and dumps response headers to the log.
type headerDumpingRoundTripper struct {
	orig http.RoundTripper
}

func (rt *headerDumpingRoundTripper) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	proxy.DumpHeaders("Request", &req.Header)
	resp, err = rt.orig.RoundTrip(req)
	if err == nil {
		proxy.DumpHeaders("Response", &resp.Header)
	}
	return
}

// buildServer builds a server configured from this serverInfo using the given
// enproxy.Config if provided.
func (serverInfo *ServerInfo) buildServer(shouldDumpHeaders bool, masquerades *verifiedMasqueradeSet, enproxyConfig *enproxy.Config) *server {
	weight := serverInfo.Weight
	if weight == 0 {
		weight = 100
	}

	server := &server{
		info:          serverInfo,
		masquerades:   masquerades,
		enproxyConfig: enproxyConfig,
	}

	if server.enproxyConfig == nil {
		// Build a dynamic config
		server.enproxyConfig = server.buildEnproxyConfig()
	}
	server.reverseProxy = server.buildReverseProxy(shouldDumpHeaders)

	return server
}

// disposableEnproxyConfig creates an enproxy.Config for one-time use (no
// pooling, etc.)
func (serverInfo *ServerInfo) disposableEnproxyConfig(masquerade *Masquerade) *enproxy.Config {
	masqueradeSource := func() *Masquerade { return masquerade }
	dial := serverInfo.dialerFor(masqueradeSource)
	dialFunc := func(addr string) (net.Conn, error) {
		return dial()
	}
	return serverInfo.enproxyConfigWith(dialFunc)
}

func (serverInfo *ServerInfo) enproxyConfigWith(dialProxy func(addr string) (net.Conn, error)) *enproxy.Config {
	return &enproxy.Config{
		DialProxy: dialProxy,
		NewRequest: func(upstreamHost string, method string, body io.Reader) (req *http.Request, err error) {
			if upstreamHost == "" {
				// No specific host requested, use configured one
				upstreamHost = serverInfo.Host
			}
			return http.NewRequest(method, "http://"+upstreamHost+"/", body)
		},
		BufferRequests: serverInfo.BufferRequests,
		IdleTimeout:    idleTimeout, // TODO: make this configurable
	}
}

func (serverInfo *ServerInfo) dialerFor(masqueradeSource func() *Masquerade) func() (net.Conn, error) {
	dialTimeout := time.Duration(serverInfo.DialTimeoutMillis) * time.Millisecond
	if dialTimeout == 0 {
		dialTimeout = 20 * time.Second
	}

	// Note - we need to suppress the sending of the ServerName in the client
	// handshake to make host-spoofing work with Fastly.  If the client Hello
	// includes a server name, Fastly checks to make sure that this matches the
	// Host header in the HTTP request and if they don't match, it returns
	// a 400 Bad Request error.
	sendServerNameExtension := false

	return func() (net.Conn, error) {
		masquerade := masqueradeSource()
		cwt, err := tlsdialer.DialForTimings(
			&net.Dialer{
				Timeout: dialTimeout,
			},
			"tcp",
			serverInfo.addressForServer(masquerade),
			sendServerNameExtension,
			serverInfo.tlsConfig(masquerade))

		domain := ""
		if masquerade != nil {
			domain = masquerade.Domain
		}

		resultAddr := ""
		if err == nil {
			resultAddr = cwt.Conn.RemoteAddr().String()
		}

		if cwt.ResolutionTime > 0 {
			serverInfo.recordTiming("DNSLookup", cwt.ResolutionTime)
			if cwt.ResolutionTime > 1*time.Second {
				log.Debugf("DNS lookup for %s (%s) took %s", domain, resultAddr, cwt.ResolutionTime)
			}
		}

		if cwt.ConnectTime > 0 {
			serverInfo.recordTiming("TCPConnect", cwt.ConnectTime)
			if cwt.ConnectTime > 5*time.Second {
				log.Debugf("TCP connecting to %s (%s) took %s", domain, resultAddr, cwt.ConnectTime)
			}
		}

		if cwt.HandshakeTime > 0 {
			serverInfo.recordTiming("TLSHandshake", cwt.HandshakeTime)
			if cwt.HandshakeTime > 5*time.Second {
				log.Debugf("TLS handshake to %s (%s) took %s", domain, resultAddr, cwt.HandshakeTime)
			}
		}

		if err != nil && masquerade != nil {
			err = fmt.Errorf("Unable to dial masquerade %s: %s", masquerade.Domain, err)
		}
		return cwt.Conn, err
	}
}

// recordTimings records timing information for the given step in establishing
// a connection. It always records that the step happened, and it records the
// highest timing threshold exceeded by the step.  Thresholds are 1, 2, 4, 8,
// and 16 seconds.
//
// For example, if calling this with step = "DNSLookup" and duration = 2.5
// seconds, we will increment two gauges, "DNSLookup" and
// "DNSLookupOver2Sec".
//
// The stats are qualified by MasqueradeSet (if specified), otherwise they're
// qualified by host. For example, if the MasqueradeSet is "cloudflare", the
// above stats would be recorded as "DNSLookupTocloudflare" and
// "DNSLookupTocloudflareOver2Sec". If the MasqueradeSet is "" and the host is
// "localhost", the stats would be recorded as "DNSLookupTolocalhost" and
// "DNSLookupTolocalhostOver2Sec".
func (serverInfo *ServerInfo) recordTiming(step string, duration time.Duration) {
	if serverInfo.MasqueradeSet != "" {
		step = fmt.Sprintf("%sTo%s", step, serverInfo.MasqueradeSet)
	} else {
		step = fmt.Sprintf("%sTo%s", step, serverInfo.Host)
	}
	statreporter.Gauge(step).Add(1)
	for i := 4; i >= 0; i-- {
		seconds := int(math.Pow(float64(2), float64(i)))
		if duration > time.Duration(seconds)*time.Second {
			key := fmt.Sprintf("%sOver%dSec", step, seconds)
			statreporter.Gauge(key).Add(1)
			return
		}
	}
}

// Get the address to dial for reaching the server
func (serverInfo *ServerInfo) addressForServer(masquerade *Masquerade) string {
	return fmt.Sprintf("%s:%d", serverInfo.serverHost(masquerade), serverInfo.Port)
}

func (serverInfo *ServerInfo) serverHost(masquerade *Masquerade) string {
	serverHost := serverInfo.Host
	if masquerade != nil {
		if masquerade.IpAddress != "" {
			serverHost = masquerade.IpAddress
		} else if masquerade.Domain != "" {
			serverHost = masquerade.Domain
		}
	}
	return serverHost
}

// tlsConfig builds a tls.Config for dialing the upstream host. Constructed
// tls.Configs are cached on a per-masquerade basis to enable client session
// caching and reduce the amount of PEM certificate parsing.
func (serverInfo *ServerInfo) tlsConfig(masquerade *Masquerade) *tls.Config {
	serverInfo.tlsConfigsMutex.Lock()
	defer serverInfo.tlsConfigsMutex.Unlock()

	if serverInfo.tlsConfigs == nil {
		serverInfo.tlsConfigs = make(map[string]*tls.Config)
	}

	configKey := ""
	serverName := serverInfo.Host
	if masquerade != nil {
		configKey = masquerade.Domain + "|" + masquerade.RootCA
		serverName = masquerade.Domain
	}
	tlsConfig := serverInfo.tlsConfigs[configKey]
	if tlsConfig == nil {
		tlsConfig = &tls.Config{
			ClientSessionCache: tls.NewLRUClientSessionCache(1000),
			InsecureSkipVerify: serverInfo.InsecureSkipVerify,
			ServerName:         serverName,
		}
		if masquerade != nil && masquerade.RootCA != "" {
			caCert, err := keyman.LoadCertificateFromPEMBytes([]byte(masquerade.RootCA))
			if err != nil {
				log.Fatalf("Unable to load root ca cert: %s", err)
			}
			tlsConfig.RootCAs = caCert.PoolContainingCert()
		}
		serverInfo.tlsConfigs[configKey] = tlsConfig
	}

	return tlsConfig
}
