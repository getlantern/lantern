package detour

import (
	"io/ioutil"
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

var (
	msg = []byte("Hello world")
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func proxy(url string) (resp *http.Response, err error) {
	return http.Get(proxiedURL)
}

func dDialer(network, addr string) (net.Conn, error) {
	return net.Dial("tcp", ":12307")
}

func TestDetour(t *testing.T) {
	startMockServers(t)
	defer stopMockServers()
	SetTimeout(50 * time.Millisecond)

	resp, err := http.Get(closeURL)
	if assert.Error(t, err, "normal access should error") {
		assert.Equal(t, err.(*url.Error).Err.Error(), "EOF", "should be EOF")
	}

	SetDetourDialer(dDialer)
	client := &http.Client{Transport: &http.Transport{Dial: Dial}, Timeout: 250 * time.Millisecond}

	resp, err = client.Get(echoURL)
	if assert.NoError(t, err, "should not error get /echo") {
		assertContent(t, resp, directMsg, "should not detour if url can be accessed")
	}
	resp, err = client.Get(timeOutURL)
	if assert.NoError(t, err, "should not error get /timeout") {
		assertContent(t, resp, detourMsg, "should detour if time out")
	}
	resp, err = client.Get(closeURL)
	if assert.NoError(t, err, "should not error get /close") {
		assertContent(t, resp, detourMsg, "should detour if connection closed with no data")
	}
}

func assertContent(t *testing.T, resp *http.Response, msg string, reason string) {
	b, err := ioutil.ReadAll(resp.Body)
	assert.NoError(t, err, reason)
	assert.Equal(t, msg, string(b), reason)
}
