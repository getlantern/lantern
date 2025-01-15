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
	"github.com/getlantern/lantern-outline/common"
	"github.com/getlantern/radiance/config"
	rtransport "github.com/getlantern/radiance/transport"
)

const (
	tcpKeepAliveInterval = 30 * time.Second
	defaultUpstream      = "test"

	authTokenHeader = "X-Lantern-Auth-Token"
)

// streamDialer is used to dial Shadowsocks proxies and wrap connections with TLS.
type streamDialer struct {
	addr         string
	dialer       transport.StreamDialer
	packetDialer transport.PacketListener
	config       *config.Config
	tlsConfig    *tls.Config
}

// NewDialer creates a new dialer from the Radiance config
func NewDialer(cfg *config.Config) (Dialer, error) {
	dialer, err := rtransport.DialerFrom(cfg)
	if err != nil {
		return nil, err
	}
	addr := fmt.Sprintf("%s:%d", cfg.Addr, cfg.Port)
	return &streamDialer{
		addr:   addr,
		dialer: dialer,
	}, nil
}

// NewShadowsocks creates a new stream dialer from the Radiance config
func NewStreamDialer(cfg *config.Config) (Dialer, error) {
	addr := fmt.Sprintf("%s:%d", cfg.Addr, cfg.Port)
	// Retrieve Shadowsocks-specific configuration.
	ssconf := cfg.GetConnectCfgShadowsocks()

	// Generate the encryption key
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
		// Extract the host from the address for ServerName configuration.
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

	// Create a new Shadowsocks stream dialer with the endpoint and encryption key
	ssDialer, err := shadowsocks.NewStreamDialer(endpoint, key)
	if err != nil {
		return nil, err
	}

	return &streamDialer{
		dialer:    ssDialer,
		addr:      addr,
		config:    cfg,
		tlsConfig: tlsConfig,
	}, nil
}

// DialStream establishes a connection to the remote address using the Shadowsocks dialer.
func (d *streamDialer) DialStream(ctx context.Context, remoteAddr string) (transport.StreamConn, error) {
	innerConn, err := d.dialer.DialStream(ctx, d.addr)
	if err != nil {
		return nil, err
	}
	if d.tlsConfig == nil {
		return innerConn, nil
	}
	// Wrap the connection with TLS.
	tlsConn := tls.Client(innerConn, d.tlsConfig)
	// Perform a custom handshake to send authentication and connect details.
	err = shakeHand(tlsConn, remoteAddr, d.config.AuthToken)
	if err != nil {
		return nil, err
	}
	if err := tlsConn.HandshakeContext(ctx); err != nil {
		return nil, err
	}
	// Return the wrapped connection as a StreamConn
	return streamConn{tlsConn, innerConn}, err
}

// DialTCP establishes a TCP connection to the target specified by the FiveTuple.
func (d *streamDialer) DialTCP(ctx context.Context, m *common.FiveTuple) (transport.StreamConn, error) {
	return d.DialStream(ctx, m.RemoteAddress())
}

// DialUDP establishes a UDP connection using the packetDialer.
func (d *streamDialer) DialUDP(m *common.FiveTuple) (net.PacketConn, error) {
	pc, err := d.packetDialer.ListenPacket(context.Background())
	if err != nil {
		return nil, err
	}
	return &packetConn{PacketConn: pc}, nil
}

// shakeHand performs an HTTP CONNECT request over the TLS connection.
func shakeHand(tlsConn *tls.Conn, remoteAddr, authToken string) error {
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

	// Read the server's response to the CONNECT request
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
