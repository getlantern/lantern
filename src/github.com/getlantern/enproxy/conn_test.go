package enproxy

import (
	"bufio"
	"bytes"
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/keyman"
	"github.com/getlantern/testify/assert"
	. "github.com/getlantern/waitforserver"
)

const (
	TEXT = "Hello byte counting world"
	HR   = "----------------------------"
)

var (
	pk   *keyman.PrivateKey
	cert *keyman.Certificate

	proxyAddr     = ""
	httpAddr      = ""
	httpsAddr     = ""
	bytesReceived = int64(0)
	bytesSent     = int64(0)
	destsReceived = make(map[string]bool)
	destsSent     = make(map[string]bool)
	statMutex     sync.Mutex
)

func TestPlainTextStreamingNoHostFn(t *testing.T) {
	doTestPlainText(false, false, t)
}

func TestPlainTextBufferedNoHostFn(t *testing.T) {
	doTestPlainText(true, false, t)
}

func TestPlainTextStreamingHostFn(t *testing.T) {
	doTestPlainText(false, true, t)
}

func TestPlainTextBufferedHostFn(t *testing.T) {
	doTestPlainText(true, true, t)
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

func TestIdle(t *testing.T) {
	idleTimeout := 100 * time.Millisecond

	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get fdcount: %v", err)
	}

	_, err = Dial(httpAddr, &Config{
		DialProxy: func(addr string) (net.Conn, error) {
			return net.Dial("tcp", proxyAddr)
		},
		NewRequest:  newRequest,
		IdleTimeout: idleTimeout,
	})
	if assert.NoError(t, err, "Dialing should have succeeded") {
		time.Sleep(idleTimeout * 2)
		assert.NoError(t, counter.AssertDelta(2), "All file descriptors except the connection from proxy to destination site should have been closed")
	}
}

// This test stimulates a connection leak as seen in
// https://github.com/getlantern/lantern/issues/2174.
func TestHTTPRedirect(t *testing.T) {
	startProxy(t, false)

	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return Dial(addr, &Config{
					DialProxy: func(addr string) (net.Conn, error) {
						return net.Dial("tcp", proxyAddr)
					},
					NewRequest: newRequest,
				})
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
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
	}

	assert.NoError(t, counter.AssertDelta(2), "All file descriptors except the connection from proxy to destination site should have been closed")
}

func doTestPlainText(buffered bool, useHostFn bool, t *testing.T) {
	var counter *fdcount.Counter
	var err error

	startServers(t, useHostFn)

	err = fdcount.WaitUntilNoneMatch("CLOSE_WAIT", 5*time.Second)
	if err != nil {
		t.Fatalf("Unable to wait until no more connections are in CLOSE_WAIT: %v", err)
	}

	_, counter, err = fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get fdcount: %v", err)
	}

	var reportedHost string
	var reportedHostMutex sync.Mutex
	onResponse := func(resp *http.Response) {
		reportedHostMutex.Lock()
		reportedHost = resp.Header.Get(X_ENPROXY_PROXY_HOST)
		reportedHostMutex.Unlock()
	}

	conn, err := prepareConn(httpAddr, buffered, false, t, onResponse)
	if err != nil {
		t.Fatalf("Unable to prepareConn: %s", err)
	}
	defer func() {
		err := conn.Close()
		assert.Nil(t, err, "Closing conn should succeed")
		if !assert.NoError(t, counter.AssertDelta(2), "All file descriptors except the connection from proxy to destination site should have been closed") {
			DumpConnTrace()
		}
	}()

	doRequests(conn, t)

	assert.Equal(t, 208, bytesReceived, "Wrong number of bytes received")
	assert.Equal(t, 284, bytesSent, "Wrong number of bytes sent")
	assert.True(t, destsSent[httpAddr], "http address wasn't recorded as sent destination")
	assert.True(t, destsReceived[httpAddr], "http address wasn't recorded as received destination")

	reportedHostMutex.Lock()
	rh := reportedHost
	reportedHostMutex.Unlock()
	assert.Equal(t, "localhost", rh, "Didn't get correct reported host")
}

func doTestTLS(buffered bool, t *testing.T) {
	startServers(t, false)

	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get fdcount: %v", err)
	}

	conn, err := prepareConn(httpsAddr, buffered, false, t, nil)
	if err != nil {
		t.Fatalf("Unable to prepareConn: %s", err)
	}

	tlsConn := tls.Client(conn, &tls.Config{
		ServerName: "localhost",
		RootCAs:    cert.PoolContainingCert(),
	})
	defer func() {
		err := conn.Close()
		assert.Nil(t, err, "Closing conn should succeed")
		if !assert.NoError(t, counter.AssertDelta(2), "All file descriptors except the connection from proxy to destination site should have been closed") {
			DumpConnTrace()
		}
	}()

	err = tlsConn.Handshake()
	if err != nil {
		t.Fatalf("Unable to handshake: %s", err)
	}

	doRequests(tlsConn, t)

	assert.True(t, destsSent[httpsAddr], "https address wasn't recorded as sent destination")
	assert.True(t, destsReceived[httpsAddr], "https address wasn't recorded as received destination")
}

func doTestBad(buffered bool, t *testing.T) {
	startServers(t, false)

	conn, err := prepareConn(httpAddr, buffered, true, t, nil)
	if err == nil {
		defer func() {
			if err := conn.Close(); err != nil {
				log.Debugf("Unable to close connection: %v", err)
			}
		}()
		t.Error("Bad conn should have returned error on Connect()")
	}
}

func prepareConn(addr string, buffered bool, fail bool, t *testing.T, onResponse func(resp *http.Response)) (conn net.Conn, err error) {
	return Dial(addr,
		&Config{
			DialProxy: func(addr string) (net.Conn, error) {
				proto := "tcp"
				if fail {
					proto = "fakebad"
				}
				return net.Dial(proto, proxyAddr)
			},
			NewRequest:      newRequest,
			BufferRequests:  buffered,
			OnFirstResponse: onResponse,
		})
}

func newRequest(host, path, method string, body io.Reader) (req *http.Request, err error) {
	return http.NewRequest(method, "http://"+proxyAddr+"/"+path+"/", body)
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
	req.Header.Add("Testcdn", "Of course!")
	if err != nil {
		t.Fatalf("Unable to create request: %s", err)
	}

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
	assert.Contains(t, text, TEXT, "Wrong text returned from server")
}

func startServers(t *testing.T, useHostFn bool) {
	startHttpServer(t)
	startHttpsServer(t)
	startProxy(t, useHostFn)
}

func startProxy(t *testing.T, useHostFn bool) {
	if proxyAddr != "" {
		statMutex.Lock()
		bytesReceived = 0
		bytesSent = 0
		destsReceived = make(map[string]bool)
		destsReceived = make(map[string]bool)
		statMutex.Unlock()
		return
	}

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Proxy unable to listen: %v", err)
	}
	proxyAddr = l.Addr().String()

	var host string
	var hostFn func(*http.Request) string

	if useHostFn {
		hostFn = func(req *http.Request) string {
			if _, found := req.Header["Testcdn"]; found {
				return "localhost"
			} else {
				return ""
			}
		}
	} else {
		host = "localhost"
	}
	go func() {
		proxy := &Proxy{
			OnBytesReceived: func(clientIp string, destAddr string, req *http.Request, bytes int64) {
				statMutex.Lock()
				bytesReceived += bytes
				destsReceived[destAddr] = true
				statMutex.Unlock()
			},
			OnBytesSent: func(clientIp string, destAddr string, req *http.Request, bytes int64) {
				statMutex.Lock()
				bytesSent += bytes
				destsSent[destAddr] = true
				statMutex.Unlock()
			},
			Host:   host,
			HostFn: hostFn,
		}
		err := proxy.Serve(l)
		if err != nil {
			t.Fatalf("Proxy unable to serve: %s", err)
		}
	}()

	if err := WaitForServer("tcp", proxyAddr, 1*time.Second); err != nil {
		t.Fatal(err)
	}
}

func startHttpServer(t *testing.T) {
	if httpAddr != "" {
		return
	}

	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("HTTP unable to listen: %v", err)
	}
	httpAddr = l.Addr().String()

	doStartServer(t, l)
}

func startHttpsServer(t *testing.T) {
	if httpsAddr != "" {
		return
	}

	var err error

	pk, err = keyman.GeneratePK(2048)
	if err != nil {
		t.Fatalf("Unable to generate key: %s", err)
	}

	// Generate self-signed certificate
	cert, err = pk.TLSCertificateFor("tlsdialer", "localhost", time.Now().Add(1*time.Hour), true, nil)
	if err != nil {
		t.Fatalf("Unable to generate cert: %s", err)
	}

	keypair, err := tls.X509KeyPair(cert.PEMEncoded(), pk.PEMEncoded())
	if err != nil {
		t.Fatalf("Unable to generate x509 key pair: %s", err)
	}

	l, err := tls.Listen("tcp", "localhost:0", &tls.Config{
		Certificates: []tls.Certificate{keypair},
	})
	if err != nil {
		t.Fatalf("HTTP unable to listen: %v", err)
	}
	httpsAddr = l.Addr().String()

	doStartServer(t, l)
}

func doStartServer(t *testing.T, l net.Listener) {
	go func() {
		httpServer := &http.Server{
			Handler: http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
				if _, err := resp.Write([]byte(TEXT)); err != nil {
					log.Debugf("Unable to write response: %v", err)
				}
			}),
		}
		err := httpServer.Serve(l)
		if err != nil {
			t.Fatalf("Unable to start http server: %s", err)
		}
	}()

	if err := WaitForServer("tcp", l.Addr().String(), 1*time.Second); err != nil {
		t.Fatal(err)
	}
}
