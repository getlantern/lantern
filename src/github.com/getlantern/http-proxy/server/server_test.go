package server

import (
	"crypto/tls"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/getlantern/keyman"
	"github.com/stretchr/testify/assert"

	"github.com/getlantern/http-proxy/commonfilter"
	"github.com/getlantern/http-proxy/filters"
	"github.com/getlantern/http-proxy/forward"
	"github.com/getlantern/http-proxy/httpconnect"
	"github.com/getlantern/http-proxy/listeners"
)

const (
	tunneledReq    = "GET / HTTP/1.1\r\n\r\n"
	originResponse = "Fight for a Free Internet!"
)

var (
	httpProxyAddr    string
	tlsProxyAddr     string
	httpOriginServer *originHandler
	httpOriginURL    string
	tlsOriginServer  *originHandler
	tlsOriginURL     string

	serverCertificate *keyman.Certificate
	// TODO: this should be imported from tlsdefaults package, but is not being
	// exported there.
	preferredCipherSuites = []uint16{
		tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
		tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
		tls.TLS_ECDHE_RSA_WITH_RC4_128_SHA,
		tls.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
		tls.TLS_RSA_WITH_RC4_128_SHA,
		tls.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
		tls.TLS_RSA_WITH_AES_128_CBC_SHA,
		tls.TLS_RSA_WITH_AES_256_CBC_SHA,
		tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
		tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
	}
)

func init() {
	testingLocal = true
}

func TestMain(m *testing.M) {
	flag.Parse()
	var err error

	// Set up mock origin servers
	httpOriginURL, httpOriginServer = newOriginHandler(originResponse, false)
	defer httpOriginServer.Close()
	tlsOriginURL, tlsOriginServer = newOriginHandler(originResponse, true)
	defer tlsOriginServer.Close()

	// Set up HTTP chained server
	httpProxyAddr, err = setupNewHTTPServer(0, 30*time.Second)
	if err != nil {
		log.Error("Error starting proxy server")
		os.Exit(1)
	}

	// Set up HTTPS chained server
	tlsProxyAddr, err = setupNewHTTPSServer(0, 30*time.Second)
	if err != nil {
		log.Error("Error starting proxy server")
		os.Exit(1)
	}

	os.Exit(m.Run())
}

func TestMaxConnections(t *testing.T) {
	connectReq := "CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n"

	addr, err := setupNewHTTPServer(5, 30*time.Second)
	if err != nil {
		assert.Fail(t, "Error starting proxy server")
	}

	//limitedServer.httpServer.SetKeepAlivesEnabled(false)
	okFn := func(conn net.Conn, originURL *url.URL) {
		req := fmt.Sprintf(connectReq, originURL.Host, originURL.Host)
		conn.Write([]byte(req))
		var buf [400]byte
		_, err := conn.Read(buf[:])

		assert.NoError(t, err)

		time.Sleep(time.Millisecond * 100)
	}

	waitFn := func(conn net.Conn, originURL *url.URL) {
		conn.SetReadDeadline(time.Now().Add(50 * time.Millisecond))

		req := fmt.Sprintf(connectReq, originURL.Host, originURL.Host)
		conn.Write([]byte(req))
		var buf [400]byte
		_, err := conn.Read(buf[:])

		if assert.Error(t, err) {
			e, ok := err.(*net.OpError)
			assert.True(t, ok && e.Timeout(), "should be a time out error")
		}
	}

	for i := 0; i < 5; i++ {
		go testRoundTrip(t, addr, false, httpOriginServer, okFn)
	}

	time.Sleep(time.Millisecond * 10)

	for i := 0; i < 5; i++ {
		go testRoundTrip(t, addr, false, httpOriginServer, waitFn)
	}

	time.Sleep(time.Millisecond * 100)

	for i := 0; i < 5; i++ {
		go testRoundTrip(t, addr, false, httpOriginServer, okFn)
	}
}

func TestIdleClientConnections(t *testing.T) {
	addr, err := setupNewHTTPServer(0, 100*time.Millisecond)
	if err != nil {
		assert.Fail(t, "Error starting proxy server")
	}

	okFn := func(conn net.Conn, originURL *url.URL) {
		time.Sleep(time.Millisecond * 90)
		conn.Write([]byte("GET / HTTP/1.1\r\nHost: www.google.com\r\n\r\n"))

		var buf [400]byte
		_, err := conn.Read(buf[:])

		assert.NoError(t, err)
	}

	idleFn := func(conn net.Conn, originURL *url.URL) {
		time.Sleep(time.Millisecond * 110)
		conn.Write([]byte("GET / HTTP/1.1\r\nHost: www.google.com\r\n\r\n"))

		var buf [400]byte
		_, err := conn.Read(buf[:])

		assert.Error(t, err)
	}

	go testRoundTrip(t, addr, false, httpOriginServer, okFn)
	testRoundTrip(t, addr, false, httpOriginServer, idleFn)
}

// A proxy with a custom origin server connection timeout
func impatientProxy(maxConns uint64, idleTimeout time.Duration) (string, error) {
	filterChain := filters.Join(
		httpconnect.New(&httpconnect.Options{
			IdleTimeout: idleTimeout,
		}),
		forward.New(&forward.Options{
			IdleTimeout: idleTimeout,
		}),
	)
	srv := NewServer(filterChain)

	// Add net.Listener wrappers for inbound connections

	srv.AddListenerWrappers(
		// Close connections after 30 seconds of no activity
		func(ls net.Listener) net.Listener {
			return listeners.NewIdleConnListener(ls, time.Second*30)
		},
	)

	ready := make(chan string)
	wait := func(addr string) {
		ready <- addr
	}
	var err error
	go func(err *error) {
		if *err = srv.ListenAndServeHTTP("localhost:0", wait); err != nil {
			log.Errorf("Unable to serve: %v", err)
		}
	}(&err)
	return <-ready, err
}

func chunkedReq(t *testing.T, buf *[400]byte, conn net.Conn, originURL *url.URL) error {
	str1tpl := "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\nHost: %s\r\n\r\n"
	str2 := "64\r\neqxnmrkoccpsnhcsrcqbuuvhvbhbcsdijcvxuglykcqxjspawibqcyzzzjacbfkmkijequeazvzinqjmamcdleeknfoqmbdwjmcb\r\n0\r\n\r\n"

	str1 := fmt.Sprintf(str1tpl, originURL.Host)
	t.Log("\n" + str1)
	conn.Write([]byte(str1))

	time.Sleep(150 * time.Millisecond)

	t.Log("\n" + str2)
	conn.Write([]byte([]byte(str2)))

	_, err := conn.Read(buf[:])

	t.Log("\n" + string(buf[:]))

	return err
}

func TestIdleOriginDirect(t *testing.T) {
	okAddr, err := impatientProxy(0, 30*time.Second)
	if err != nil {
		assert.Fail(t, "Error starting proxy server: %s", err)
	}

	impatientAddr, err := impatientProxy(0, 50*time.Millisecond)
	if err != nil {
		assert.Fail(t, "Error starting proxy server: %s", err)
	}

	okForwardFn := func(conn net.Conn, originURL *url.URL) {
		var buf [400]byte
		chunkedReq(t, &buf, conn, originURL)
		assert.Contains(t, string(buf[:]), "200 OK", "should succeed")
	}

	failForwardFn := func(conn net.Conn, originURL *url.URL) {
		var buf [400]byte
		chunkedReq(t, &buf, conn, originURL)
		assert.Contains(t, string(buf[:]), "502 Bad Gateway", "should fail with 502")
	}

	testRoundTrip(t, okAddr, false, httpOriginServer, okForwardFn)
	testRoundTrip(t, impatientAddr, false, httpOriginServer, failForwardFn)
}

func TestIdleOriginConnect(t *testing.T) {
	okAddr, err := impatientProxy(0, 30*time.Second)
	if err != nil {
		assert.Fail(t, "Error starting proxy server: %s", err)
	}

	impatientAddr, err := impatientProxy(0, 50*time.Millisecond)
	if err != nil {
		assert.Fail(t, "Error starting proxy server: %s", err)
	}

	connectReq := func(conn net.Conn, originURL *url.URL) error {
		reqStr := "CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n"
		req := fmt.Sprintf(reqStr, originURL.Host, originURL.Host)
		conn.Write([]byte(req))
		var buf [400]byte
		conn.Read(buf[:])

		return chunkedReq(t, &buf, conn, originURL)
	}

	okConnectFn := func(conn net.Conn, originURL *url.URL) {
		err := connectReq(conn, originURL)

		assert.NoError(t, err, "should succeed")
	}

	failConnectFn := func(conn net.Conn, originURL *url.URL) {
		err := connectReq(conn, originURL)

		assert.Error(t, err, "should fail")
	}

	testRoundTrip(t, okAddr, false, httpOriginServer, okConnectFn)
	testRoundTrip(t, impatientAddr, false, httpOriginServer, failConnectFn)
}

// X-Lantern-Auth-Token + X-Lantern-Device-Id -> 200 OK <- Tunneled request -> 200 OK
func TestConnectOK(t *testing.T) {
	connectReq := "CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n"
	connectResp := "HTTP/1.1 200 OK\r\n"

	testHTTP := func(conn net.Conn, originURL *url.URL) {
		req := fmt.Sprintf(connectReq, originURL.Host, originURL.Host)
		t.Log("\n" + req)
		_, err := conn.Write([]byte(req))
		if !assert.NoError(t, err, "should write CONNECT request") {
			t.FailNow()
		}

		var buf [400]byte
		_, err = conn.Read(buf[:])
		if !assert.Contains(t, string(buf[:]), connectResp,
			"should get 200 OK") {
			t.FailNow()
		}

		_, err = conn.Write([]byte(tunneledReq))
		if !assert.NoError(t, err, "should write tunneled data") {
			t.FailNow()
		}

		buf = [400]byte{}
		conn.Read(buf[:])
		assert.Contains(t, string(buf[:]), originResponse, "should read tunneled response")
	}

	testTLS := func(conn net.Conn, originURL *url.URL) {
		req := fmt.Sprintf(connectReq, originURL.Host, originURL.Host)
		t.Log("\n" + req)
		_, err := conn.Write([]byte(req))
		if !assert.NoError(t, err, "should write CONNECT request") {
			t.FailNow()
		}

		var buf [400]byte
		_, err = conn.Read(buf[:])
		if !assert.Contains(t, string(buf[:]), connectResp,
			"should get 200 OK") {
			t.FailNow()
		}

		// HTTPS-Tunneled HTTPS
		tunnConn := tls.Client(conn, &tls.Config{
			InsecureSkipVerify: true,
		})
		tunnConn.Handshake()

		_, err = tunnConn.Write([]byte(tunneledReq))
		if !assert.NoError(t, err, "should write tunneled data") {
			t.FailNow()
		}

		buf = [400]byte{}
		tunnConn.Read(buf[:])
		assert.Contains(t, string(buf[:]), originResponse, "should read tunneled response")
	}

	testRoundTrip(t, httpProxyAddr, false, httpOriginServer, testHTTP)
	testRoundTrip(t, tlsProxyAddr, true, httpOriginServer, testHTTP)

	testRoundTrip(t, httpProxyAddr, false, tlsOriginServer, testTLS)
	testRoundTrip(t, tlsProxyAddr, true, tlsOriginServer, testTLS)
}

// X-Lantern-Auth-Token + X-Lantern-Device-Id -> Forward
func TestDirectOK(t *testing.T) {
	reqTempl := "GET /%s HTTP/1.1\r\nHost: %s\r\n\r\n"
	failResp := "HTTP/1.1 500 Internal Server Error\r\n"

	testOk := func(conn net.Conn, originURL *url.URL) {
		req := fmt.Sprintf(reqTempl, originURL.Path, originURL.Host)
		t.Log("\n" + req)
		_, err := conn.Write([]byte(req))
		if !assert.NoError(t, err, "should write GET request") {
			t.FailNow()
		}

		buf := [400]byte{}
		conn.Read(buf[:])
		assert.Contains(t, string(buf[:]), originResponse, "should read tunneled response")

	}

	testFail := func(conn net.Conn, originURL *url.URL) {
		req := fmt.Sprintf(reqTempl, originURL.Path, originURL.Host)
		t.Log("\n" + req)
		_, err := conn.Write([]byte(req))
		if !assert.NoError(t, err, "should write GET request") {
			t.FailNow()
		}

		buf := [400]byte{}
		conn.Read(buf[:])
		t.Log("\n" + string(buf[:]))

		assert.Contains(t, string(buf[:]), failResp, "should respond with 500 Internal Server Error")

	}

	testRoundTrip(t, httpProxyAddr, false, httpOriginServer, testOk)
	testRoundTrip(t, tlsProxyAddr, true, httpOriginServer, testOk)

	// HTTPS can't be tunneled using Direct Proxying, as redirections
	// require a TLS handshake between the proxy and the origin
	testRoundTrip(t, httpProxyAddr, false, tlsOriginServer, testFail)
	testRoundTrip(t, tlsProxyAddr, true, tlsOriginServer, testFail)
}

func TestInvalidRequest(t *testing.T) {
	connectResp := "HTTP/1.1 400 Bad Request\r\n"
	testFn := func(conn net.Conn, originURL *url.URL) {
		_, err := conn.Write([]byte("GET HTTP/1.1\r\n\r\n"))
		if !assert.NoError(t, err, "should write GET request") {
			t.FailNow()
		}

		buf := [400]byte{}
		conn.Read(buf[:])
		assert.Contains(t, string(buf[:]), connectResp, "should 400")

	}
	for i := 0; i < 10; i++ {
		testRoundTrip(t, httpProxyAddr, false, tlsOriginServer, testFn)
		testRoundTrip(t, tlsProxyAddr, true, tlsOriginServer, testFn)
	}
}

func TestDisconnectingServer(t *testing.T) {
	addr, err := setupNewDisconnectingServer(0, 5*time.Second)
	if err != nil {
		assert.Fail(t, "Error starting proxy server")
	}

	t.Logf("Dialing %v", addr)
	conn, err := net.Dial("tcp", addr)
	if !assert.NoError(t, err, "Should be able to connect") {
		return
	}

	time.Sleep(500 * time.Millisecond)
	_, err = conn.Write([]byte("GET HTTP/1.1\r\n\r\n"))
	if !assert.NoError(t, err) {
		return
	}

	out, err := ioutil.ReadAll(conn)
	if !assert.NoError(t, err) {
		return
	}
	assert.Empty(t, string(out), "Server shouldn't have sent anything")
}

//
// Auxiliary functions
//

func testRoundTrip(t *testing.T, addr string, isTLS bool, origin *originHandler, checkerFn func(conn net.Conn, originURL *url.URL)) {
	var conn net.Conn
	var err error

	if !isTLS {
		conn, err = net.Dial("tcp", addr)
		log.Debugf("%s -> %s (via HTTP) -> %s", conn.LocalAddr().String(), addr, origin.server.URL)
		if !assert.NoError(t, err, "should dial proxy server") {
			t.FailNow()
		}
	} else {
		var tlsConn *tls.Conn
		x509cert := serverCertificate.X509()
		tlsConn, err = tls.Dial("tcp", addr, &tls.Config{
			CipherSuites:       preferredCipherSuites,
			InsecureSkipVerify: true,
		})
		log.Debugf("%s -> %s (via HTTPS) -> %s", tlsConn.LocalAddr().String(), addr, origin.server.URL)
		if !assert.NoError(t, err, "should dial proxy server") {
			t.FailNow()
		}
		conn = tlsConn
		if !tlsConn.ConnectionState().PeerCertificates[0].Equal(x509cert) {
			if err := tlsConn.Close(); err != nil {
				log.Errorf("Error closing chained server connection: %s", err)
			}
			t.Fatal("Server's certificate didn't match expected")
		}
	}
	defer func() {
		assert.NoError(t, conn.Close(), "should close connection")
	}()

	url, _ := url.Parse(origin.server.URL)
	checkerFn(conn, url)
}

//
// Proxy server
//

type proxy struct {
	protocol string
	addr     string
}

func basicServer(maxConns uint64, idleTimeout time.Duration) *Server {
	filterChain := filters.Join(
		commonfilter.New(&commonfilter.Options{
			AllowLocalhost: testingLocal,
		}),
		httpconnect.New(&httpconnect.Options{
			IdleTimeout: idleTimeout,
		}),
		forward.New(&forward.Options{
			IdleTimeout: idleTimeout,
		}),
	)
	// Create server
	srv := NewServer(filterChain)

	// Add net.Listener wrappers for inbound connections
	srv.AddListenerWrappers(
		// Limit max number of simultaneous connections
		func(ls net.Listener) net.Listener {
			return listeners.NewLimitedListener(ls, maxConns)
		},
		// Close connections after 30 seconds of no activity
		func(ls net.Listener) net.Listener {
			return listeners.NewIdleConnListener(ls, idleTimeout)
		},
	)

	return srv
}

func setupNewHTTPServer(maxConns uint64, idleTimeout time.Duration) (string, error) {
	s := basicServer(maxConns, idleTimeout)
	var err error
	ready := make(chan string)
	wait := func(addr string) {
		log.Debugf("Started HTTP proxy server at %s", addr)
		ready <- addr
	}
	go func(err *error) {
		if *err = s.ListenAndServeHTTP("localhost:0", wait); err != nil {
			log.Errorf("Unable to serve: %v", err)
		}
	}(&err)
	return <-ready, err
}

func setupNewHTTPSServer(maxConns uint64, idleTimeout time.Duration) (string, error) {
	s := basicServer(maxConns, idleTimeout)
	var err error
	ready := make(chan string)
	wait := func(addr string) {
		log.Debugf("Started HTTPS proxy server at %s", addr)

		ready <- addr
	}
	go func(err *error) {
		if *err = s.ListenAndServeHTTPS("localhost:0", "key.pem", "cert.pem", wait); err != nil {
			log.Errorf("Unable to serve: %v", err)
		}
	}(&err)
	addr := <-ready
	if err != nil {
		return "", err
	}
	serverCertificate, err = keyman.LoadCertificateFromFile("cert.pem")
	return addr, err
}

func setupNewDisconnectingServer(maxConns uint64, idleTimeout time.Duration) (string, error) {
	s := basicServer(maxConns, idleTimeout)
	s.Allow = func(ip string) bool {
		return false
	}

	var err error
	ready := make(chan string)
	wait := func(addr string) {
		log.Debugf("Started disconnecting HTTP proxy server at %s", addr)
		ready <- addr
	}
	go func(err *error) {
		if *err = s.ListenAndServeHTTP("localhost:0", wait); err != nil {
			log.Errorf("Unable to serve: %v", *err)
		}
	}(&err)
	return <-ready, err
}

//
// Mock origin server
// Emulating locally an origin server for testing tunnels
//

type originHandler struct {
	writer func(w http.ResponseWriter)
	server *httptest.Server
}

func (m *originHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	m.writer(w)
}

func (m *originHandler) Raw(msg string) {
	m.writer = func(w http.ResponseWriter) {
		conn, _, _ := w.(http.Hijacker).Hijack()
		if _, err := conn.Write([]byte(msg)); err != nil {
			log.Errorf("Unable to write to connection: %v", err)
		}
		if err := conn.Close(); err != nil {
			log.Errorf("Unable to close connection: %v", err)
		}
	}
}

func (m *originHandler) Msg(msg string) {
	m.writer = func(w http.ResponseWriter) {
		w.Header()["Content-Length"] = []string{strconv.Itoa(len(msg))}
		_, _ = w.Write([]byte(msg))
		w.(http.Flusher).Flush()
	}
}

func (m *originHandler) Timeout(d time.Duration, msg string) {
	m.writer = func(w http.ResponseWriter) {
		time.Sleep(d)
		w.Header()["Content-Length"] = []string{strconv.Itoa(len(msg))}
		_, _ = w.Write([]byte(msg))
		w.(http.Flusher).Flush()
	}
}

func (m *originHandler) Close() {
	m.server.Close()
}

func newOriginHandler(msg string, tls bool) (string, *originHandler) {
	m := originHandler{}
	m.Msg(msg)
	m.server = httptest.NewUnstartedServer(&m)
	m.server.Config.AcceptAnyHostHeader = true
	if tls {
		m.server.StartTLS()
	} else {
		m.server.Start()
	}
	log.Debugf("Started origin server at %v", m.server.URL)
	return m.server.URL, &m
}
