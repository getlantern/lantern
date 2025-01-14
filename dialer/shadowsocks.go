package dialer

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"net"
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

// ssDialer is used to dial shadowsocks proxies
type ssDialer struct {
	*streamDialer

	tlsConfig *tls.Config
}

// NewShadowsocks creates a new Shadowsocks based dialer
func NewShadowsocks(cfg *config.Config) (Dialer, error) {
	return newShadowsocks(cfg)
}

func newShadowsocks(cfg *config.Config) (*ssDialer, error) {
	addr := fmt.Sprintf("%s:%d", cfg.Addr, cfg.Port)
	ssconf := cfg.GetConnectCfgShadowsocks()

	key, err := shadowsocks.NewEncryptionKey(ssconf.Cipher, ssconf.Secret)
	if err != nil {
		return nil, err
	}
	var tlsConfig *tls.Config
	ssconf.WithTls = false
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
	dialer, err := shadowsocks.NewStreamDialer(endpoint, key)
	if err != nil {
		return nil, err
	}

	return &ssDialer{
		tlsConfig:    tlsConfig,
		streamDialer: newStreamDialer(addr, cfg, dialer),
	}, nil
}

func (d *ssDialer) DialStream(ctx context.Context, remoteAddr string) (transport.StreamConn, error) {
	log.Debug("Here..")
	innerConn, err := d.streamDialer.DialStream(ctx, d.addr)
	if err != nil {
		return nil, err
	}
	if d.tlsConfig == nil {
		return innerConn, nil
	}
	tlsConn := tls.Client(innerConn, d.tlsConfig)
	err = shakeHand(tlsConn, remoteAddr, d.config.AuthToken)
	if err != nil {
		return nil, err
	}
	if err := tlsConn.HandshakeContext(ctx); err != nil {
		return nil, err
	}
	return streamConn{tlsConn, innerConn}, err
}
