package chained

import (
	"bufio"
	"fmt"
	"net"
	"net/http"
	"strings"

	"github.com/getlantern/proxy"
)

// Config is a configuration for a Dialer.
type Config struct {
	// DialServer: function that dials the upstream server proxy
	DialServer func() (net.Conn, error)

	// OnRequest: optional function that gets called on every CONNECT request to
	// the server and is allowed to modify the http.Request before it passes to
	// the server.
	OnRequest func(req *http.Request)
}

// dialer is an implementation of proxy.Dialer that proxies traffic via an
// upstream server proxy.  Its Dial function uses DialServer to dial the server
// proxy and then issues a CONNECT request to instruct the server to connect to
// the destination at the specified network and addr.
type dialer struct {
	Config
}

// NewDialer creates a dialer{} based on the given Config.
func NewDialer(cfg Config) proxy.Dialer {
	return &dialer{Config: cfg}
}

// Dial implements the method from proxy.Dialer
func (d *dialer) Dial(network, addr string) (net.Conn, error) {
	conn, err := d.DialServer()
	if err != nil {
		return nil, fmt.Errorf("Unable to dial server: %s", err)
	}
	err = d.sendCONNECT(network, addr, conn)
	if err != nil {
		conn.Close()
		return nil, err
	}
	return conn, nil
}

// Close implements the method from proxy.Dialer
func (d *dialer) Close() error {
	return nil
}

func (d *dialer) sendCONNECT(network, addr string, conn net.Conn) error {
	if !strings.Contains(network, "tcp") {
		return fmt.Errorf("%s connections are not supported, only tcp is supported", network)
	}

	req, err := buildCONNECTRequest(addr, d.OnRequest)
	if err != nil {
		return fmt.Errorf("Unable to construct CONNECT request: %s", err)
	}
	err = req.Write(conn)
	if err != nil {
		return fmt.Errorf("Unable to write CONNECT request: %s", err)
	}

	r := bufio.NewReader(conn)
	err = checkCONNECTResponse(r, req)
	return err
}

func buildCONNECTRequest(addr string, onRequest func(req *http.Request)) (*http.Request, error) {
	req, err := http.NewRequest(httpConnectMethod, addr, nil)
	if err != nil {
		return nil, err
	}
	req.Host = addr
	if onRequest != nil {
		onRequest(req)
	}
	return req, nil
}

func checkCONNECTResponse(r *bufio.Reader, req *http.Request) error {
	resp, err := http.ReadResponse(r, req)
	if err != nil {
		return fmt.Errorf("Error reading CONNECT response: %s", err)
	}
	if resp.StatusCode < http.StatusOK || resp.StatusCode > 299 {
		return fmt.Errorf("Bad status code on CONNECT response: %d", resp.StatusCode)
	}
	return nil
}
