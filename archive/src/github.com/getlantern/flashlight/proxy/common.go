// package proxy provides the implementations of the client and server proxies
package proxy

import (
	"crypto/tls"
	"net/http"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("flashlight.proxy")
)

// ProxyConfig encapsulates common proxy configuration
type ProxyConfig struct {
	ShouldDumpHeaders bool          // whether or not to dump headers of requests and responses
	Addr              string        // listen address in form of host:port
	ReadTimeout       time.Duration // (optional) timeout for read ops
	WriteTimeout      time.Duration // (optional) timeout for write ops
	TLSConfig         *tls.Config   // (optional) TLS configuration for inbound connections, if nil then DEFAULT_TLS_SERVER_CONFIG is used
}

const (
	X_LANTERN_PUBLIC_IP = "X-LANTERN-PUBLIC-IP" // Client's public IP as seen by the proxy

	HR = "--------------------------------------------------------------------------------"
)

// DumpHeaders logs the given headers (request or response).
func DumpHeaders(category string, headers *http.Header) {
	log.Debugf("%s Headers\n%s\n%s\n%s\n\n", category, HR, spew.Sdump(headers), HR)
}
