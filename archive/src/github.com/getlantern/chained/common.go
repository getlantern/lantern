// Package chained provides a chained proxy that can proxy any tcp traffic over
// any underlying transport through a remote proxy. The downstream (client) side
// of the chained setup is just a dial function. The upstream (server) side is
// just an http.Handler. The client tells the server where to connect using an
// HTTP CONNECT request.
package chained

import (
	"github.com/getlantern/golog"
)

const (
	httpConnectMethod = "CONNECT"
)

var (
	log = golog.LoggerFor("chained")
)
