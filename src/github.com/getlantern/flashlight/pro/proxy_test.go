package pro

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"runtime"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestProxy(t *testing.T) {
	m := &mockRoundTripper{msg: "GOOD"}
	httpClient.Set(&http.Client{Transport: m})
	addr := pickFreeAddr()
	url := fmt.Sprintf("http://%s/abc", addr)
	ddfURL := fmt.Sprintf("http://%s/abc", proAPIDDFHost)
	go func() {
		t.Logf("Launching test server at %s", url)
		InitProxy(addr)
	}()
	// Give InitProxy a chance to run
	runtime.Gosched()

	req, err := http.NewRequest("OPTIONS", url, nil)
	if err != nil {
		panic(err)
	}
	req.Header.Set("Origin", "a.com")
	resp, err := (&http.Client{}).Do(req)
	if assert.NoError(t, err, "OPTIONS request should succeed") {
		assert.Equal(t, 200, resp.StatusCode, "should respond 200 to OPTIONS")
		assert.Equal(t, "a.com", resp.Header.Get("Access-Control-Allow-Origin"), "should respond with correct header")
		_ = resp.Body.Close()
	}
	assert.Nil(t, m.req, "should not pass the OPTIONS request to origin server")

	req, err = http.NewRequest("GET", url, nil)
	req.Header.Set("Origin", "a.com")
	resp, err = (&http.Client{}).Do(req)
	if assert.NoError(t, err, "GET request should have no error") {
		assert.Equal(t, 200, resp.StatusCode, "should respond 200 ok")
		assert.Equal(t, "a.com", resp.Header.Get("Access-Control-Allow-Origin"), "should respond with correct header")
		msg, _ := ioutil.ReadAll(resp.Body)
		_ = resp.Body.Close()
		assert.Equal(t, "GOOD", string(msg), "should respond expected body")
	}
	if assert.NotNil(t, m.req, "should pass through non-OPTIONS requests to origin server") {
		t.Log(m.req)
		assert.Empty(t, m.req.Header.Get("Origin"), "should strip off Origin header")
		assert.Equal(t, ddfURL, m.req.Header.Get("Lantern-Fronted-URL"), "should set fronted URL")
	}
}

type mockRoundTripper struct {
	req *http.Request
	msg string
}

func (m *mockRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	m.req = req
	resp := &http.Response{
		StatusCode: 200,
		Header:     http.Header{},
		Body:       ioutil.NopCloser(strings.NewReader(m.msg)),
	}
	return resp, nil
}

func pickFreeAddr() (addr string) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		panic(err)
	}
	addr = l.Addr().(*net.TCPAddr).String()
	l.Close()
	return
}
