package client

import (
	"net"
	"net/http"

	"github.com/getlantern/enproxy"
	"github.com/getlantern/flashlight/globals"
)

// HttpClient creates a simple domain-fronted HTTP client using the specified
// values for the upstream host to use and for the masquerade/domain fronted host.
func HttpClient(serverInfo *ServerInfo, masquerade *Masquerade) *http.Client {
	if masquerade != nil && globals.TrustedCAs == nil {
		serverInfo.InsecureSkipVerify = true
	}

	enproxyConfig := serverInfo.disposableEnproxyConfig(masquerade)

	return &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				conn := &enproxy.Conn{
					Addr:   addr,
					Config: enproxyConfig,
				}
				err := conn.Connect()
				if err != nil {
					return nil, err
				}
				return conn, nil
			},
		},
	}
}
