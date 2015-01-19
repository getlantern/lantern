package enproxy

import (
	"bufio"
	"bytes"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
	. "github.com/getlantern/waitforserver"
)

const (
	PROXY_ADDR    = "localhost:13091"
	EXPECTED_TEXT = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers."
	HR            = "----------------------------"
)

var (
	proxyStarted  = false
	bytesReceived = int64(0)
	bytesSent     = int64(0)
)

func TestPlainTextStreaming(t *testing.T) {
	doTestPlainText(false, t)
}

func TestPlainTextBuffered(t *testing.T) {
	doTestPlainText(true, t)
}

func TestTLSStreaming(t *testing.T) {
	doTestTLS(false, t)
}

func TestTLSBuffered(t *testing.T) {
	doTestTLS(true, t)
}

func TestBadStreaming(t *testing.T) {
	doTestBad(false, t)
}

func TestBadBuffered(t *testing.T) {
	doTestBad(true, t)
}

// This test stimulates a connection leak as seen in
// https://github.com/getlantern/lantern/issues/2174.
func TestHTTPRedirect(t *testing.T) {
	startProxy(t)

	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				conn := &Conn{
					Addr: addr,
					Config: &Config{
						DialProxy: func(addr string) (net.Conn, error) {
							return net.Dial("tcp", PROXY_ADDR)
						},
						NewRequest: func(upstreamHost string, method string, body io.Reader) (req *http.Request, err error) {
							return http.NewRequest(method, "http://"+PROXY_ADDR+"/", body)
						},
					},
				}
				err := conn.Connect()
				if err != nil {
					return nil, err
				}
				return conn, nil
			},
			DisableKeepAlives: true,
		},
	}

	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get fdcount: %v", err)
	}

	resp, err := client.Head("http://www.facebook.com")
	if assert.NoError(t, err, "Head request to facebook should have succeeded") {
		resp.Body.Close()
	}

	assert.NoError(t, counter.AssertDelta(2), "All file descriptors except the connection from proxy to destination site should have been closed")
}

func doTestPlainText(buffered bool, t *testing.T) {
	startProxy(t)

	conn, err := prepareConn(80, buffered, false, t)
	if err != nil {
		t.Fatalf("Unable to prepareConn: %s", err)
	}
	defer conn.Close()

	doRequests(conn, t)

	if bytesReceived != 226 {
		t.Errorf("Bytes received of %d did not match expected %d", bytesReceived, 226)
	}
	if bytesSent != 1378 {
		t.Errorf("Bytes sent of %d did not match expected %d", bytesSent, 1378)
	}
}

func doTestTLS(buffered bool, t *testing.T) {
	startProxy(t)

	conn, err := prepareConn(443, buffered, false, t)
	if err != nil {
		t.Fatalf("Unable to prepareConn: %s", err)
	}

	tlsConn := tls.Client(conn, &tls.Config{
		ServerName: "www.google.com",
	})
	defer tlsConn.Close()

	err = tlsConn.Handshake()
	if err != nil {
		t.Fatalf("Unable to handshake: %s", err)
	}

	doRequests(tlsConn, t)

	if bytesReceived != 555 {
		t.Errorf("Bytes received of %d did not match expected %d", bytesReceived, 555)
	}
	if bytesSent != 5010 {
		t.Errorf("Bytes sent of %d did not match expected %d", bytesSent, 5010)
	}
}

func doTestBad(buffered bool, t *testing.T) {
	startProxy(t)

	conn, err := prepareConn(80, buffered, true, t)
	if err == nil {
		defer conn.Close()
		t.Error("Bad conn should have returned error on Connect()")
	}
}

func prepareConn(port int, buffered bool, fail bool, t *testing.T) (conn *Conn, err error) {
	addr := fmt.Sprintf("%s:%d", "www.google.com", port)
	conn = &Conn{
		Addr: addr,
		Config: &Config{
			DialProxy: func(addr string) (net.Conn, error) {
				proto := "tcp"
				if fail {
					proto = "fakebad"
				}
				return net.Dial(proto, PROXY_ADDR)
			},
			NewRequest: func(host string, method string, body io.Reader) (req *http.Request, err error) {
				if host == "" {
					host = PROXY_ADDR
				}
				return http.NewRequest(method, "http://"+host, body)
			},
			BufferRequests: buffered,
		},
	}
	err = conn.Connect()
	return
}

func doRequests(conn net.Conn, t *testing.T) {
	// Single request/response pair
	req := makeRequest(conn, t)
	readResponse(conn, req, t)

	// Consecutive request/response pairs
	req = makeRequest(conn, t)
	readResponse(conn, req, t)
}

func makeRequest(conn net.Conn, t *testing.T) *http.Request {
	req, err := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
	if err != nil {
		t.Fatalf("Unable to create request: %s", err)
	}
	req.Header.Set("Proxy-Connection", "keep-alive")
	go func() {
		err = req.Write(conn)
		if err != nil {
			t.Fatalf("Unable to write request: %s", err)
		}
	}()
	return req
}

func readResponse(conn net.Conn, req *http.Request, t *testing.T) {
	buffIn := bufio.NewReader(conn)
	resp, err := http.ReadResponse(buffIn, req)
	if err != nil {
		t.Fatalf("Unable to read response: %s", err)
	}

	buff := bytes.NewBuffer(nil)
	_, err = io.Copy(buff, resp.Body)
	if err != nil {
		t.Fatalf("Unable to read response body: %s", err)
	}
	text := string(buff.Bytes())
	if !strings.Contains(text, EXPECTED_TEXT) {
		t.Errorf("Resulting string did not contain expected text.\nExpected:\n%s\n%s\nReceived:\n%s", EXPECTED_TEXT, HR, text)
	}
}

func startProxy(t *testing.T) {
	if proxyStarted {
		atomic.StoreInt64(&bytesReceived, 0)
		atomic.StoreInt64(&bytesSent, 0)
		return
	}

	go func() {
		proxy := &Proxy{
			OnBytesReceived: func(clientIp string, bytes int64) {
				atomic.AddInt64(&bytesReceived, bytes)
			},
			OnBytesSent: func(clientIp string, bytes int64) {
				atomic.AddInt64(&bytesSent, bytes)
			},
		}
		err := proxy.ListenAndServe(PROXY_ADDR)
		if err != nil {
			t.Fatalf("Unable to listen and serve: %s", err)
		}
	}()
	if err := WaitForServer("tcp", PROXY_ADDR, 1*time.Second); err != nil {
		t.Fatal(err)
	}
	proxyStarted = true
}
