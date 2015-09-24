// package fronted provides a client and server for domain-fronted proxying
// using enproxy proxies.
package fronted

import (
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/connpool"
	"github.com/getlantern/enproxy"
	"github.com/getlantern/golog"
	"github.com/getlantern/proxy"
	"github.com/getlantern/tlsdialer"
)

const (
	CONNECT = "CONNECT" // HTTP CONNECT method
)

var (
	log = golog.LoggerFor("fronted")

	// Cutoff for logging warnings about a dial having taken a long time.
	longDialLimit = 10 * time.Second

	// idleTimeout needs to be small enough that we stop using connections
	// before the upstream server/CDN closes them itself.
	// TODO: make this configurable.
	idleTimeout = 10 * time.Second
)

// Dialer is a domain-fronted proxy.Dialer.
type Dialer interface {
	proxy.Dialer

	// HttpClientUsing creates a simple domain-fronted HTTP client using the
	// specified Masquerade.
	HttpClientUsing(masquerade *Masquerade) *http.Client
}

// Config captures the configuration of a domain-fronted dialer.
type Config struct {
	// Host: the host (e.g. getiantem.org)
	Host string

	// Port: the port (e.g. 443)
	Port int

	// Masquerades: the Masquerades to use when domain-fronting. These will be
	// verified when the Dialer starts.
	Masquerades []*Masquerade

	// MaxMasquerades: the maximum number of masquerades to verify. If 0,
	// the masquerades are uncapped.
	MaxMasquerades int

	// PoolSize: if greater than 0, outbound connections will be pooled in an
	// eagerly loading connection pool. This can reduce latency when using
	// enproxy.
	PoolSize int

	// InsecureSkipVerify: if true, server's certificate is not verified.
	InsecureSkipVerify bool

	// BufferRequests: if true, requests to the proxy will be buffered and sent
	// with identity encoding.  If false, they'll be streamed with chunked
	// encoding.
	BufferRequests bool

	// DialTimeoutMillis: how long to wait on dialing server before timing out
	// (defaults to 30 seconds)
	DialTimeoutMillis int

	// RedialAttempts: number of times to try redialing. The total number of
	// dial attempts will be 1 + RedialAttempts.
	RedialAttempts int

	// Weight: relative weight versus other servers (for round-robin)
	Weight int

	// QOS: relative quality of service offered. Should be >= 0, with higher
	// values indicating higher QOS.
	QOS int

	// OnDial: optional callback that gets invoked whenever we dial the server.
	// The Conn and error returned from this callback will be used in lieu of
	// the originals.
	OnDial func(conn net.Conn, err error) (net.Conn, error)

	// OnDialStats is an optional callback that will get called on every dial to
	// the server to report stats on what was dialed and how long each step
	// took.
	OnDialStats func(success bool, domain, addr string, resolutionTime, connectTime, handshakeTime time.Duration)
}

// dialer implements the proxy.Dialer interface by dialing domain-fronted
// servers.
type dialer struct {
	Config
	masquerades     *verifiedMasqueradeSet
	connPool        connpool.Pool
	enproxyConfig   *enproxy.Config
	tlsConfigs      map[string]*tls.Config
	tlsConfigsMutex sync.Mutex
}

// NewDialer creates a new Dialer for the given Config.
// WARNING - depending on configuration, this Dialer may contain a connection
// pool and/or a set of Masquerades that will leak resources.  Make sure to call
// Close() to clean these up when the Dialer is no longer in use.
func NewDialer(cfg Config) Dialer {
	d := &dialer{
		Config:     cfg,
		tlsConfigs: make(map[string]*tls.Config),
	}
	if d.Masquerades != nil {
		if d.MaxMasquerades == 0 {
			d.MaxMasquerades = len(d.Masquerades)
		}
		d.masquerades = d.verifiedMasquerades()
	}
	if cfg.PoolSize > 0 {
		d.connPool = connpool.New(connpool.Config{
			Size:         cfg.PoolSize,
			ClaimTimeout: idleTimeout,
			Dial:         d.dialServer,
		})
	}
	d.enproxyConfig = d.enproxyConfigWith(func(addr string) (net.Conn, error) {
		var conn net.Conn
		var err error
		if d.connPool != nil {
			conn, err = d.connPool.Get()
		} else {
			conn, err = d.dialServer()
		}
		if d.OnDial != nil {
			conn, err = d.OnDial(conn, err)
		}
		return conn, err
	})
	return d
}

// Dial dials upstream using domain-fronting.
func (d *dialer) Dial(network, addr string) (net.Conn, error) {
	if !strings.Contains(network, "tcp") {
		return nil, fmt.Errorf("Protocol %s is not supported, only tcp is supported", network)
	}

	return enproxy.Dial(addr, d.enproxyConfig)
}

// Close closes the dialer, in particular closing the underlying connection
// pool.
func (d *dialer) Close() error {
	if d.connPool != nil {
		// We close the connPool on a goroutine so as not to wait for Close to finish
		go d.connPool.Close()
	}
	if d.masquerades != nil {
		go d.masquerades.stop()
	}
	return nil
}

func (d *dialer) HttpClientUsing(masquerade *Masquerade) *http.Client {
	enproxyConfig := d.enproxyConfigWith(func(addr string) (net.Conn, error) {
		return d.dialServerWith(masquerade)
	})

	return &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return enproxy.Dial(addr, enproxyConfig)
			},
		},
	}
}

func (d *dialer) enproxyConfigWith(dialProxy func(addr string) (net.Conn, error)) *enproxy.Config {
	return &enproxy.Config{
		DialProxy: dialProxy,
		NewRequest: func(upstreamHost, path, method string, body io.Reader) (req *http.Request, err error) {
			if upstreamHost == "" {
				// No specific host requested, use configured one
				upstreamHost = d.Host
			}
			return http.NewRequest(method, "http://"+upstreamHost+"/"+path+"/", body)
		},
		BufferRequests: d.BufferRequests,
		IdleTimeout:    idleTimeout, // TODO: make this configurable
	}
}

func (d *dialer) dialServer() (net.Conn, error) {
	var masquerade *Masquerade
	if d.masquerades != nil {
		masquerade = d.masquerades.nextVerified()
	}
	return d.dialServerWith(masquerade)
}

func (d *dialer) dialServerWith(masquerade *Masquerade) (net.Conn, error) {
	dialTimeout := time.Duration(d.DialTimeoutMillis) * time.Millisecond
	if dialTimeout == 0 {
		dialTimeout = 30 * time.Second
	}

	// Note - we need to suppress the sending of the ServerName in the client
	// handshake to make host-spoofing work with Fastly.  If the client Hello
	// includes a server name, Fastly checks to make sure that this matches the
	// Host header in the HTTP request and if they don't match, it returns
	// a 400 Bad Request error.
	sendServerNameExtension := false

	cwt, err := tlsdialer.DialForTimings(
		&net.Dialer{
			Timeout: dialTimeout,
		},
		"tcp",
		d.addressForServer(masquerade),
		sendServerNameExtension,
		d.tlsConfig(masquerade))

	if d.OnDialStats != nil {
		domain := ""
		if masquerade != nil {
			domain = masquerade.Domain
		}

		resultAddr := ""
		if err == nil {
			resultAddr = cwt.Conn.RemoteAddr().String()
		}

		d.OnDialStats(err == nil, domain, resultAddr, cwt.ResolutionTime, cwt.ConnectTime, cwt.HandshakeTime)
	}

	if err != nil && masquerade != nil {
		err = fmt.Errorf("Unable to dial masquerade %s: %s", masquerade.Domain, err)
	}
	return cwt.Conn, err
}

// Get the address to dial for reaching the server
func (d *dialer) addressForServer(masquerade *Masquerade) string {
	return fmt.Sprintf("%s:%d", d.serverHost(masquerade), d.Port)
}

func (d *dialer) serverHost(masquerade *Masquerade) string {
	serverHost := d.Host
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
func (d *dialer) tlsConfig(masquerade *Masquerade) *tls.Config {
	d.tlsConfigsMutex.Lock()
	defer d.tlsConfigsMutex.Unlock()

	serverName := d.Host
	if masquerade != nil {
		serverName = masquerade.Domain
	}
	tlsConfig := d.tlsConfigs[serverName]
	if tlsConfig == nil {
		tlsConfig = &tls.Config{
			ClientSessionCache: tls.NewLRUClientSessionCache(1000),
			InsecureSkipVerify: d.InsecureSkipVerify,
			ServerName:         serverName,
			RootCAs:            getCertPool(),
		}
		d.tlsConfigs[serverName] = tlsConfig
	}

	return tlsConfig
}
