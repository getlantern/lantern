package dialer

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/Jigsaw-Code/outline-sdk/transport/shadowsocks"
	"github.com/getlantern/radiance/config"
)

const (
	tcpKeepAliveInterval = 30 * time.Second
	defaultUpstream      = "test"

	authTokenHeader = "X-Lantern-Auth-Token"
)

// streamDialer is used to dial shadowsocks proxies
type streamDialer struct {
	*dialer

	config    *config.Config
	tlsConfig *tls.Config
}

// NewShadowsocks creates a new Shadowsocks based dialer
func NewShadowsocks(cfg *config.Config) (Dialer, error) {
	addr := fmt.Sprintf("%s:%d", cfg.Addr, cfg.Port)
	ssconf := cfg.GetConnectCfgShadowsocks()

	key, err := shadowsocks.NewEncryptionKey(ssconf.Cipher, ssconf.Secret)
	if err != nil {
		return nil, err
	}
	var tlsConfig *tls.Config
	if ssconf.WithTls {
		certPool := x509.NewCertPool()
		if ok := certPool.AppendCertsFromPEM(cfg.CertPem); !ok {
			return nil, errors.New("couldn't add certificate to pool")
		}
		ip, _, err := net.SplitHostPort(addr)
		if err != nil {
			return nil, fmt.Errorf("couldn't split host and port: %v", err)
		}

		tlsConfig = &tls.Config{
			RootCAs:            certPool,
			InsecureSkipVerify: true,
			ServerName:         ip,
		}
	}

	endpoint := &transport.TCPEndpoint{Address: addr}
	ssDialer, err := shadowsocks.NewStreamDialer(endpoint, key)
	if err != nil {
		return nil, err
	}

	return &streamDialer{
		dialer: &dialer{
			StreamDialer: ssDialer,
			addr:         addr,
		},
		config:    cfg,
		tlsConfig: tlsConfig,
	}, nil
}

func (d *streamDialer) DialStream(ctx context.Context, remoteAddr string) (transport.StreamConn, error) {
	innerConn, err := d.StreamDialer.DialStream(ctx, d.addr)
	if err != nil {
		return nil, err
	}
	if d.tlsConfig == nil {
		return innerConn, nil
	}
	tlsConn := tls.Client(innerConn, d.tlsConfig)
	err = shakeHand(ctx, tlsConn, remoteAddr, d.config.AuthToken)
	if err != nil {
		return nil, err
	}
	if err := tlsConn.HandshakeContext(ctx); err != nil {
		return nil, err
	}
	return streamConn{tlsConn, innerConn}, err
}

func shakeHand(ctx context.Context, tlsConn *tls.Conn, remoteAddr, authToken string) error {
	// Create a new CONNECT request to send to the proxy server.
	connectReq := &http.Request{
		Method: http.MethodConnect,
		URL: &url.URL{
			Scheme: "https",
			Host:   remoteAddr,
		},
		// CONNECT request should always include port in req.Host.
		// Ref https://tools.ietf.org/html/rfc2817#section-5.2.
		Host: remoteAddr,
		Header: http.Header{
			authTokenHeader:    []string{authToken},
			"Proxy-Connection": []string{"Keep-Alive"},
		},
	}
	if err := connectReq.Write(tlsConn); err != nil {
		return err
	}

	// Read the response to ensure the CONNECT request succeeded
	resp, err := http.ReadResponse(bufio.NewReader(tlsConn), connectReq)
	if err != nil {
		return fmt.Errorf("failed to read CONNECT response: %v", err)
	}
	defer resp.Body.Close()

	// Check if the response status is OK (200)
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("CONNECT request failed: %s", resp.Status)
	}
	return nil
}
