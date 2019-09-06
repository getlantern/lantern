// Copyright 2013 The Gorilla WebSocket Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package websocket

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"reflect"
	"strings"
	"testing"
	"time"
)

var cstUpgrader = Upgrader{
	Subprotocols:    []string{"p0", "p1"},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	Error: func(w http.ResponseWriter, r *http.Request, status int, reason error) {
		http.Error(w, reason.Error(), status)
	},
}

var cstDialer = Dialer{
	Subprotocols:    []string{"p1", "p2"},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

type cstHandler struct{ *testing.T }

type cstServer struct {
	*httptest.Server
	URL string
}

const (
	cstPath       = "/a/b"
	cstRawQuery   = "x=y"
	cstRequestURI = cstPath + "?" + cstRawQuery
)

func newServer(t *testing.T) *cstServer {
	var s cstServer
	s.Server = httptest.NewServer(cstHandler{t})
	s.Server.URL += cstRequestURI
	s.URL = makeWsProto(s.Server.URL)
	return &s
}

func newTLSServer(t *testing.T) *cstServer {
	var s cstServer
	s.Server = httptest.NewTLSServer(cstHandler{t})
	s.Server.URL += cstRequestURI
	s.URL = makeWsProto(s.Server.URL)
	return &s
}

func (t cstHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != cstPath {
		t.Logf("path=%v, want %v", r.URL.Path, cstPath)
		http.Error(w, "bad path", 400)
		return
	}
	if r.URL.RawQuery != cstRawQuery {
		t.Logf("query=%v, want %v", r.URL.RawQuery, cstRawQuery)
		http.Error(w, "bad path", 400)
		return
	}
	subprotos := Subprotocols(r)
	if !reflect.DeepEqual(subprotos, cstDialer.Subprotocols) {
		t.Logf("subprotols=%v, want %v", subprotos, cstDialer.Subprotocols)
		http.Error(w, "bad protocol", 400)
		return
	}
	ws, err := cstUpgrader.Upgrade(w, r, http.Header{"Set-Cookie": {"sessionID=1234"}})
	if err != nil {
		t.Logf("Upgrade: %v", err)
		return
	}
	defer ws.Close()

	if ws.Subprotocol() != "p1" {
		t.Logf("Subprotocol() = %s, want p1", ws.Subprotocol())
		ws.Close()
		return
	}
	op, rd, err := ws.NextReader()
	if err != nil {
		t.Logf("NextReader: %v", err)
		return
	}
	wr, err := ws.NextWriter(op)
	if err != nil {
		t.Logf("NextWriter: %v", err)
		return
	}
	if _, err = io.Copy(wr, rd); err != nil {
		t.Logf("NextWriter: %v", err)
		return
	}
	if err := wr.Close(); err != nil {
		t.Logf("Close: %v", err)
		return
	}
}

func makeWsProto(s string) string {
	return "ws" + strings.TrimPrefix(s, "http")
}

func sendRecv(t *testing.T, ws *Conn) {
	const message = "Hello World!"
	if err := ws.SetWriteDeadline(time.Now().Add(time.Second)); err != nil {
		t.Fatalf("SetWriteDeadline: %v", err)
	}
	if err := ws.WriteMessage(TextMessage, []byte(message)); err != nil {
		t.Fatalf("WriteMessage: %v", err)
	}
	if err := ws.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
		t.Fatalf("SetReadDeadline: %v", err)
	}
	_, p, err := ws.ReadMessage()
	if err != nil {
		t.Fatalf("ReadMessage: %v", err)
	}
	if string(p) != message {
		t.Fatalf("message=%s, want %s", p, message)
	}
}

func TestProxyDial(t *testing.T) {

	s := newServer(t)
	defer s.Close()

	surl, _ := url.Parse(s.URL)

	cstDialer.Proxy = http.ProxyURL(surl)

	connect := false
	origHandler := s.Server.Config.Handler

	// Capture the request Host header.
	s.Server.Config.Handler = http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			if r.Method == "CONNECT" {
				connect = true
				w.WriteHeader(200)
				return
			}

			if !connect {
				t.Log("connect not recieved")
				http.Error(w, "connect not recieved", 405)
				return
			}
			origHandler.ServeHTTP(w, r)
		})

	ws, _, err := cstDialer.Dial(s.URL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()
	sendRecv(t, ws)

	cstDialer.Proxy = http.ProxyFromEnvironment
}

func TestProxyAuthorizationDial(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	surl, _ := url.Parse(s.URL)
	surl.User = url.UserPassword("username", "password")
	cstDialer.Proxy = http.ProxyURL(surl)

	connect := false
	origHandler := s.Server.Config.Handler

	// Capture the request Host header.
	s.Server.Config.Handler = http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			proxyAuth := r.Header.Get("Proxy-Authorization")
			expectedProxyAuth := "Basic " + base64.StdEncoding.EncodeToString([]byte("username:password"))
			if r.Method == "CONNECT" && proxyAuth == expectedProxyAuth {
				connect = true
				w.WriteHeader(200)
				return
			}

			if !connect {
				t.Log("connect with proxy authorization not recieved")
				http.Error(w, "connect with proxy authorization not recieved", 405)
				return
			}
			origHandler.ServeHTTP(w, r)
		})

	ws, _, err := cstDialer.Dial(s.URL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()
	sendRecv(t, ws)

	cstDialer.Proxy = http.ProxyFromEnvironment
}

func TestDial(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	ws, _, err := cstDialer.Dial(s.URL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()
	sendRecv(t, ws)
}

func TestDialTLS(t *testing.T) {
	s := newTLSServer(t)
	defer s.Close()

	certs := x509.NewCertPool()
	for _, c := range s.TLS.Certificates {
		roots, err := x509.ParseCertificates(c.Certificate[len(c.Certificate)-1])
		if err != nil {
			t.Fatalf("error parsing server's root cert: %v", err)
		}
		for _, root := range roots {
			certs.AddCert(root)
		}
	}

	u, _ := url.Parse(s.URL)
	d := cstDialer
	d.NetDial = func(network, addr string) (net.Conn, error) { return net.Dial(network, u.Host) }
	d.TLSClientConfig = &tls.Config{RootCAs: certs}
	ws, _, err := d.Dial("wss://example.com"+cstRequestURI, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()
	sendRecv(t, ws)
}

func xTestDialTLSBadCert(t *testing.T) {
	// This test is deactivated because of noisy logging from the net/http package.
	s := newTLSServer(t)
	defer s.Close()

	ws, _, err := cstDialer.Dial(s.URL, nil)
	if err == nil {
		ws.Close()
		t.Fatalf("Dial: nil")
	}
}

func xTestDialTLSNoVerify(t *testing.T) {
	s := newTLSServer(t)
	defer s.Close()

	d := cstDialer
	d.TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	ws, _, err := d.Dial(s.URL, nil)
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()
	sendRecv(t, ws)
}

func TestDialTimeout(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	d := cstDialer
	d.HandshakeTimeout = -1
	ws, _, err := d.Dial(s.URL, nil)
	if err == nil {
		ws.Close()
		t.Fatalf("Dial: nil")
	}
}

func TestDialBadScheme(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	ws, _, err := cstDialer.Dial(s.Server.URL, nil)
	if err == nil {
		ws.Close()
		t.Fatalf("Dial: nil")
	}
}

func TestDialBadOrigin(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	ws, resp, err := cstDialer.Dial(s.URL, http.Header{"Origin": {"bad"}})
	if err == nil {
		ws.Close()
		t.Fatalf("Dial: nil")
	}
	if resp == nil {
		t.Fatalf("resp=nil, err=%v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("status=%d, want %d", resp.StatusCode, http.StatusForbidden)
	}
}

func TestDialBadHeader(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	for _, k := range []string{"Upgrade",
		"Connection",
		"Sec-Websocket-Key",
		"Sec-Websocket-Version",
		"Sec-Websocket-Protocol"} {
		h := http.Header{}
		h.Set(k, "bad")
		ws, _, err := cstDialer.Dial(s.URL, http.Header{"Origin": {"bad"}})
		if err == nil {
			ws.Close()
			t.Errorf("Dial with header %s returned nil", k)
		}
	}
}

func TestBadMethod(t *testing.T) {
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ws, err := cstUpgrader.Upgrade(w, r, nil)
		if err == nil {
			t.Errorf("handshake succeeded, expect fail")
			ws.Close()
		}
	}))
	defer s.Close()

	resp, err := http.PostForm(s.URL, url.Values{})
	if err != nil {
		t.Fatalf("PostForm returned error %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("Status = %d, want %d", resp.StatusCode, http.StatusMethodNotAllowed)
	}
}

func TestHandshake(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	ws, resp, err := cstDialer.Dial(s.URL, http.Header{"Origin": {s.URL}})
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()

	var sessionID string
	for _, c := range resp.Cookies() {
		if c.Name == "sessionID" {
			sessionID = c.Value
		}
	}
	if sessionID != "1234" {
		t.Error("Set-Cookie not received from the server.")
	}

	if ws.Subprotocol() != "p1" {
		t.Errorf("ws.Subprotocol() = %s, want p1", ws.Subprotocol())
	}
	sendRecv(t, ws)
}

func TestRespOnBadHandshake(t *testing.T) {
	const expectedStatus = http.StatusGone
	const expectedBody = "This is the response body."

	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(expectedStatus)
		io.WriteString(w, expectedBody)
	}))
	defer s.Close()

	ws, resp, err := cstDialer.Dial(makeWsProto(s.URL), nil)
	if err == nil {
		ws.Close()
		t.Fatalf("Dial: nil")
	}

	if resp == nil {
		t.Fatalf("resp=nil, err=%v", err)
	}

	if resp.StatusCode != expectedStatus {
		t.Errorf("resp.StatusCode=%d, want %d", resp.StatusCode, expectedStatus)
	}

	p, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("ReadFull(resp.Body) returned error %v", err)
	}

	if string(p) != expectedBody {
		t.Errorf("resp.Body=%s, want %s", p, expectedBody)
	}
}

// TestHostHeader confirms that the host header provided in the call to Dial is
// sent to the server.
func TestHostHeader(t *testing.T) {
	s := newServer(t)
	defer s.Close()

	specifiedHost := make(chan string, 1)
	origHandler := s.Server.Config.Handler

	// Capture the request Host header.
	s.Server.Config.Handler = http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			specifiedHost <- r.Host
			origHandler.ServeHTTP(w, r)
		})

	ws, _, err := cstDialer.Dial(s.URL, http.Header{"Host": {"testhost"}})
	if err != nil {
		t.Fatalf("Dial: %v", err)
	}
	defer ws.Close()

	if gotHost := <-specifiedHost; gotHost != "testhost" {
		t.Fatalf("gotHost = %q, want \"testhost\"", gotHost)
	}

	sendRecv(t, ws)
}
