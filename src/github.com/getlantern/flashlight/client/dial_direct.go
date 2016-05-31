// +build !android

package client

import (
	"net"
	"time"
)

func dialDirect(network, addr string, timeout time.Duration) (net.Conn, error) {
	return net.DialTimeout(network, addr, timeout)
}
