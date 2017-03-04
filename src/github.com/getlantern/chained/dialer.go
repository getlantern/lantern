package chained

import (
	"bufio"
	"fmt"
	"net"
	"net/http"
	"strings"

	"github.com/getlantern/bandwidth"
	"github.com/getlantern/errors"
)

// Config is a configuration for a Dialer.
type Config struct {
	// DialServer: function that dials the upstream server proxy
	DialServer func() (net.Conn, error)

	// OnRequest: optional function that gets called on every CONNECT request to
	// the server and is allowed to modify the http.Request before it passes to
	// the server.
	OnRequest func(req *http.Request)

	// Label: a optional label for debugging.
	Label string
}

// dialer provides an implementation of net.Dial that proxies traffic via an
// upstream server proxy. Its Dial function uses DialServer to dial the server
// proxy and then issues a CONNECT request to instruct the server to connect to
// the destination at the specified network and addr.
type dialer struct {
	Config
}

// NewDialer returns an implementation of net.Dial() based on the given Config.
func NewDialer(cfg Config) func(network, addr string) (net.Conn, error) {
	d := &dialer{Config: cfg}
	return d.Dial
}

// Dial is a net.Dial-compatible function.
func (d *dialer) Dial(network, addr string) (net.Conn, error) {
	conn, err := d.DialServer()
	if err != nil {
		return nil, errors.New("Unable to dial server %v: %s", d.Label, err)
	}
	// Look for our special hacked "connect" transport used to signal
	// that we should send a CONNECT request and tunnel all traffic through
	// that.
	if network == "connect" {
		log.Tracef("Sending CONNECT REQUEST")
		if err := d.sendCONNECT("tcp", addr, conn); err != nil {
			// We discard this error, since we are only interested in sendCONNECT
			_ = conn.Close()
			return nil, err
		}
	}
	return conn, nil
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
	if !sameStatusCodeClass(http.StatusOK, resp.StatusCode) {
		return fmt.Errorf("Bad status code on CONNECT response: %d", resp.StatusCode)
	}
	bandwidth.Track(resp)
	return nil
}

func sameStatusCodeClass(statusCode1 int, statusCode2 int) bool {
	// HTTP response status code "classes" come in ranges of 100.
	const classRange = 100
	// These are all integers, so division truncates.
	return statusCode1/classRange == statusCode2/classRange
}
