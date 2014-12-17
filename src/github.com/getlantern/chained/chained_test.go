package chained

import (
	"bufio"
	"fmt"
	"net"
	"net/http"
	"testing"

	"github.com/getlantern/proxy"
	"github.com/getlantern/testify/assert"
)

func TestBadDialServer(t *testing.T) {
	dialer := &Dialer{
		DialServer: func() (net.Conn, error) {
			return nil, fmt.Errorf("I refuse to dial")
		},
	}
	_, err := dialer.Dial("tcp", "www.google.com")
	assert.Error(t, err, "Dialing with a bad DialServer function should have failed")
}

func TestBadProtocol(t *testing.T) {
	dialer := &Dialer{
		DialServer: func() (net.Conn, error) {
			return net.Dial("tcp", "www.google.com")
		},
	}
	_, err := dialer.Dial("udp", "www.google.com")
	assert.Error(t, err, "Dialing with a non-tcp protocol should have failed")
}

func TestBadServer(t *testing.T) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	go func() {
		conn, err := l.Accept()
		if err == nil {
			conn.Close()
		}
	}()

	dialer := &Dialer{
		DialServer: func() (net.Conn, error) {
			return net.Dial("tcp", l.Addr().String())
		},
	}
	_, err = dialer.Dial("tcp", "www.google.com")
	assert.Error(t, err, "Dialing a server that disconnects too soon should have failed")
}

func TestBadConnectStatus(t *testing.T) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	hs := &http.Server{
		Handler: http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
			resp.WriteHeader(403) // forbidden
		}),
	}
	go hs.Serve(l)

	dialer := &Dialer{
		DialServer: func() (net.Conn, error) {
			return net.Dial("tcp", l.Addr().String())
		},
	}
	_, err = dialer.Dial("tcp", "www.google.com")
	assert.Error(t, err, "Dialing a server that sends a non-successful HTTP status to our CONNECT request should have failed")
}

func TestBadMethodToServer(t *testing.T) {
	l := startServer(t)
	resp, err := http.Get("http://" + l.Addr().String() + "/")
	assert.NoError(t, err, "Making a Get request to the server should not have errored")
	if err == nil {
		assert.True(t, resp.StatusCode == 405, "Response should have indicated a bad method")
	}
}

func TestBadAddressToServer(t *testing.T) {
	l := startServer(t)
	req, err := buildCONNECTRequest("somebadaddressasdfdasfds.asdfasdf.dfads:532400", nil)
	if err != nil {
		t.Fatalf("Unable to build request: %s", err)
	}
	conn, err := net.Dial("tcp", l.Addr().String())
	if err != nil {
		t.Fatalf("Unable to dial server: %s", err)
	}
	err = req.Write(conn)
	if err != nil {
		t.Fatalf("Unable to make request: %s", err)
	}

	r := bufio.NewReader(conn)
	err = checkCONNECTResponse(r, req)
	assert.Error(t, err, "Connect response should be bad")
}

func TestSuccessNotPipelined(t *testing.T) {
	doTest(t, false)
}

func TestSuccessPipelined(t *testing.T) {
	doTest(t, true)
}

func doTest(t *testing.T, pipelined bool) {
	l := startServer(t)

	dialer := &Dialer{
		DialServer: func() (net.Conn, error) {
			return net.Dial(l.Addr().Network(), l.Addr().String())
		},
		Pipelined: false,
	}

	proxy.Test(t, dialer)
}

func startServer(t *testing.T) net.Listener {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}

	s := &Server{
		Dial: net.Dial,
	}
	go func() {
		err := s.Serve(l)
		if err != nil {
			t.Fatalf("Unable to serve: %s", err)
		}
	}()

	return l
}
