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

func TestBlockedImmediately(t *testing.T) {
	TimeoutToDetour = 50 * time.Millisecond
	url, mock := startMockServers(t)
	defer stopMockServers()

	mock.Timeout(1 * time.Second)
	client := &http.Client{Timeout: 250 * time.Millisecond}
	resp, err := client.Get(url)
	assert.Error(t, err, "direct access to a timeout url should fail")

	client = &http.Client{Transport: &http.Transport{Dial: Dialer(dDialer)}, Timeout: 250 * time.Millisecond}
	resp, err = client.Get("http://255.0.0.1") // it's reserved for future use so will always time out
	if assert.NoError(t, err, "should have no error if dialing times out") {
		assertContent(t, resp, detourMsg, "should detour if dialing times out")
	}

	resp, err = client.Get(url)
	if assert.NoError(t, err, "should have no error if reading times out") {
		assertContent(t, resp, detourMsg, "should detour if reading times out")
	}
}

func TestBlockedAfterwards(t *testing.T) {
	TimeoutToDetour = 50 * time.Millisecond
	url, mock := startMockServers(t)
	defer stopMockServers()

	client := &http.Client{Transport: &http.Transport{Dial: Dialer(dDialer)}, Timeout: 250 * time.Millisecond}
	mock.Msg(directMsg)
	resp, err := client.Get(url)
	if assert.NoError(t, err, "should have no error for normal response") {
		assertContent(t, resp, directMsg, "should access directly for normal response")
	}
	mock.Timeout(1 * time.Second)
	_, err = client.Get(url)
	assert.Error(t, err, "should have no error if reading times out")
	resp, err = client.Get(url)
	if assert.NoError(t, err, "should have no error if reading times out") {
		assertContent(t, resp, detourMsg, "should detour if reading times out")
	}
}

func TestIran(t *testing.T) {
	SetCountry("IR")
	url, mock := startMockServers(t)
	defer stopMockServers()
	client := &http.Client{Transport: &http.Transport{Dial: Dialer(dDialer)}, Timeout: 250 * time.Millisecond}
	mock.Raw(iranResp)
	resp, err := client.Get(url)
	if assert.NoError(t, err, "should not error if blocked in Iran") {
		assertContent(t, resp, detourMsg, "should detour if blocked in Iran")
	}

	// this test can verifies dns hijack detection if runs inside Iran,
	// the url will time out and detour if runs outside Iran
	resp, err = client.Get("http://" + iranRedirectIP)
	if assert.NoError(t, err, "should not error if blocked in Iran") {
		assertContent(t, resp, detourMsg, "should detour if blocked in Iran")
	}
}

func assertContent(t *testing.T, resp *http.Response, msg string, reason string) {
	b, err := ioutil.ReadAll(resp.Body)
	assert.NoError(t, err, reason)
	assert.Equal(t, msg, string(b), reason)
}
