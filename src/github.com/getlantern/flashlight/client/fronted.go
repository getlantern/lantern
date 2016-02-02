package client

import (
	"fmt"

	"github.com/getlantern/balancer"
	"github.com/getlantern/fronted"
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
