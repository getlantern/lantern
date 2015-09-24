package client

import (
	"fmt"
	"math"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/fronted"

	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/statreporter"
)

// FrontedServerInfo captures configuration information for an upstream domain-
// fronted server.
type FrontedServerInfo struct {
	// Host: the host (e.g. getiantem.org)
	Host string

	// Port: the port (e.g. 443)
	Port int

	// PoolSize: size of connection pool to use. 0 disables connection pooling.
	PoolSize int

	// MasqueradeSet: the name of the masquerade set from ClientConfig that
	// contains masquerade hosts to use for this server.
	MasqueradeSet string

	// MaxMasquerades: the maximum number of masquerades to verify. If 0,
	// the masquerades are uncapped.
	MaxMasquerades int

	// InsecureSkipVerify: if true, server's certificate is not verified.
	InsecureSkipVerify bool

	// BufferRequests: if true, requests to the proxy will be buffered and sent
	// with identity encoding.  If false, they'll be streamed with chunked
	// encoding.
	BufferRequests bool

	// DialTimeoutMillis: how long to wait on dialing server before timing out
	// (defaults to 5 seconds)
	DialTimeoutMillis int

	// RedialAttempts: number of times to try redialing. The total number of
	// dial attempts will be 1 + RedialAttempts.
	RedialAttempts int

	// Weight: relative weight versus other servers (for round-robin)
	Weight int

	// QOS: relative quality of service offered. Should be >= 0, with higher
	// values indicating higher QOS.
	QOS int

	// Trusted: Determines if a host can be trusted with unencrypted HTTP
	// traffic.
	Trusted bool
}

// dialer creates a dialer for domain fronting and and balanced dialer that can
// be used to dial to arbitrary addresses.
func (s *FrontedServerInfo) dialer(masqueradeSets map[string][]*fronted.Masquerade) (fronted.Dialer, *balancer.Dialer) {
	fd := fronted.NewDialer(fronted.Config{
		Host:               s.Host,
		Port:               s.Port,
		PoolSize:           s.PoolSize,
		InsecureSkipVerify: s.InsecureSkipVerify,
		BufferRequests:     s.BufferRequests,
		DialTimeoutMillis:  s.DialTimeoutMillis,
		RedialAttempts:     s.RedialAttempts,
		OnDial:             withStats,
		OnDialStats:        s.onDialStats,
		Masquerades:        masqueradeSets[s.MasqueradeSet],
		MaxMasquerades:     s.MaxMasquerades,
	})

	var masqueradeQualifier string
	if s.MasqueradeSet != "" {
		masqueradeQualifier = fmt.Sprintf(" using masquerade set %s", s.MasqueradeSet)
	}

	var trusted string
	if s.Trusted {
		trusted = "(trusted) "
	}

	bal := &balancer.Dialer{
		Label:   fmt.Sprintf("%sfronted proxy at %s:%d%s", trusted, s.Host, s.Port, masqueradeQualifier),
		Weight:  s.Weight,
		QOS:     s.QOS,
		Dial:    fd.Dial,
		Trusted: s.Trusted,
		OnClose: func() {
			if err := fd.Close(); err != nil {
				log.Debugf("Unable to close fronted dialer: %q", err)
			}
		},
	}

	return fd, bal
}

func (s *FrontedServerInfo) onDialStats(success bool, domain, addr string, resolutionTime, connectTime, handshakeTime time.Duration) {
	if resolutionTime > 0 {
		s.recordTiming("DNSLookup", resolutionTime)
		if resolutionTime > 1*time.Second {
			log.Debugf("DNS lookup for %s (%s) took %s", domain, addr, resolutionTime)
		}
	}

	if connectTime > 0 {
		s.recordTiming("TCPConnect", connectTime)
		if connectTime > 5*time.Second {
			log.Debugf("TCP connecting to %s (%s) took %s", domain, addr, connectTime)
		}
	}

	if handshakeTime > 0 {
		s.recordTiming("TLSHandshake", handshakeTime)
		if handshakeTime > 5*time.Second {
			log.Debugf("TLS handshake to %s (%s) took %s", domain, addr, handshakeTime)
		}
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
func (s *FrontedServerInfo) recordTiming(step string, duration time.Duration) {
	if s.MasqueradeSet != "" {
		step = fmt.Sprintf("%sTo%s", step, s.MasqueradeSet)
	} else {
		step = fmt.Sprintf("%sTo%s", step, s.Host)
	}
	dims := statreporter.Dim("country", geolookup.GetCountry())
	dims.Gauge(step).Add(1)
	for i := 4; i >= 0; i-- {
		seconds := int(math.Pow(float64(2), float64(i)))
		if duration > time.Duration(seconds)*time.Second {
			key := fmt.Sprintf("%sOver%dSec", step, seconds)
			dims.Gauge(key).Add(1)
			return
		}
	}
}
