package client

import (
	"net"
	"time"

	"github.com/getlantern/protected"
)

// Bypass VPN on Android
func dialDirect(network, addr string, timeout time.Duration) (net.Conn, error) {
	return protected.Dial(network, addr, timeout)
}
