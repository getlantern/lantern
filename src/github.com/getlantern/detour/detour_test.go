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

func init() {
	rand.Seed(time.Now().UnixNano())
}

func dDialer(network, addr string) (net.Conn, error) {
	u, _ := url.Parse(proxiedURL)
	return net.Dial("tcp", u.Host)
}

func TestDetour(t *testing.T) {
	startMockServers(t)
	defer stopMockServers()
	SetTimeout(50 * time.Millisecond)

	client := &http.Client{Timeout: 250 * time.Millisecond}
	resp, err := client.Get(timeoutURL)
	assert.Error(t, err, "direct access to a timeout url should error")

	client = &http.Client{Transport: &http.Transport{Dial: Dialer(dDialer)}, Timeout: 250 * time.Millisecond}
	resp, err = client.Get(timeoutURL)
	if assert.NoError(t, err, "should not error get /timeout") {
		assertContent(t, resp, detourMsg, "should detour if time out")
	}
	resp, err = client.Get(timeout2ndTimeURL)
	if assert.NoError(t, err, "should not error get /timeout") {
		assertContent(t, resp, directMsg, "should not detour first time")
	}
	resp, err = client.Get(timeout2ndTimeURL)
	if assert.Error(t, err, "should error get /timeout second time") {
		_, in := whitelist[timeout2ndTimeURL]
		assert.Equal(t, true, in, "should be add to whitelist")
	}
	resp, err = client.Get("http://nonexist.com")
	if assert.NoError(t, err, "should not error get an nonexist site") {
		assertContent(t, resp, detourMsg, "should detour when accessing nonexist url")
	}
	resp, err = client.Get(echoURL)
	if assert.NoError(t, err, "should not error get /echo") {
		assertContent(t, resp, directMsg, "should not detour if url can be accessed")
	}
}

func assertContent(t *testing.T, resp *http.Response, msg string, reason string) {
	b, err := ioutil.ReadAll(resp.Body)
	assert.NoError(t, err, reason)
	assert.Equal(t, msg, string(b), reason)
}
