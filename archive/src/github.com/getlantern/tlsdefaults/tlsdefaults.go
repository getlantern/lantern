// Package tlsdefaults provides sensible defaults for using TLS.
package tlsdefaults

import (
	"crypto/tls"
)

// Server provides a tls.Config with sensible defaults for server use. At this
// point, it mostly trusts the defaults from Go (assumes Go version 1.5 or
// or newer).
func Server() *tls.Config {
	return &tls.Config{
		PreferServerCipherSuites: true,
	}
}
