package detour

import (
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

var (
	directMsg = "hello direct"
	detourMsg = "hello detour"
	iranResp  = `HTTP/1.1 403 Forbidden
Connection:close

<html><head><meta http-equiv="Content-Type" content="text/html; charset=windows-1256"><title>M1-6
</title></head><body><iframe src="http://10.10.34.34?type=Invalid Site&policy=MainPolicy " style="width: 100%; height: 100%" scrolling="no" marginwidth="0" marginheight="0" frameborder="0" vspace="0" hspace="0"></iframe></body></html>Connection closed by foreign host.`
)

func init() {
	TimeoutToConnect = 150 * time.Millisecond
	DelayBeforeDetour = 50 * time.Millisecond
}

func TestTampering(t *testing.T) {
	defer stopMockServers()
	proxiedURL, _ := newMockServer(detourMsg)

	client := newClient(proxiedURL, 100*time.Millisecond)
	resp, err := client.Get("http://255.0.0.1") // it's reserved for future use so will always time out
	if assert.NoError(t, err, "should have no error when dial a timeout host") {
		time.Sleep(50 * time.Millisecond)
		assert.True(t, wlTemporarily("255.0.0.1:80"), "should be added to whitelist if dialing times out")
		assertContent(t, resp, detourMsg, "should detour if dialing times out")
	}

	client = newClient(proxiedURL, 100*time.Millisecond)
	resp, err = client.Get("http://127.0.0.1:4325") // hopefully this port didn't open, so connection will be refused
	if assert.NoError(t, err, "should have no error if connection is refused") {
		time.Sleep(60 * time.Millisecond)
		assert.True(t, wlTemporarily("127.0.0.1:4325"), "should be added to whitelist if connection is refused")
		assertContent(t, resp, detourMsg, "should detour if connection is refused")
	}
}

func TestReadTimeout(t *testing.T) {
	defer stopMockServers()
	proxiedURL, _ := newMockServer(detourMsg)
	mockURL, mock := newMockServer("")
	mock.Timeout(200*time.Millisecond, directMsg)

	client := &http.Client{Timeout: 100 * time.Millisecond}
	resp, err := client.Get(mockURL)
	assert.Error(t, err, "direct access to a timeout url should fail")

	u, _ := url.Parse(mockURL)
	client = newClient(proxiedURL, 100*time.Millisecond)
	resp, err = client.Get(mockURL)
	if assert.NoError(t, err, "should have no error if reading times out") {
		time.Sleep(50 * time.Millisecond)
		assert.True(t, wlTemporarily(u.Host), "should be added to whitelist if reading times out")
		assertContent(t, resp, detourMsg, "should detour if reading times out")
	}
}

func TestNonIdempotentOp(t *testing.T) {
	defer stopMockServers()
	proxiedURL, _ := newMockServer(detourMsg)
	mockURL, mock := newMockServer("")
	u, _ := url.Parse(mockURL)
	mock.Timeout(200*time.Millisecond, directMsg)
	client := newClient(proxiedURL, 100*time.Millisecond)
	_, err := client.PostForm(mockURL, url.Values{"key": []string{"value"}})
	if assert.Error(t, err, "Non-idempotent method should not be detoured in same connection") {
		time.Sleep(50 * time.Millisecond)
		assert.True(t, wlTemporarily(u.Host), "but should be added to whitelist so will detour next time")
	}
}

func TestBlockedAfterwards(t *testing.T) {
	defer stopMockServers()
	proxiedURL, _ := newMockServer(detourMsg)
	mockURL, mock := newMockServer(directMsg)
	client := newClient(proxiedURL, 100*time.Millisecond)

	mock.Msg(directMsg)
	resp, err := client.Get(mockURL)
	if assert.NoError(t, err, "should have no error for normal response") {
		assertContent(t, resp, directMsg, "should access directly for normal response")
	}
	mock.Timeout(200*time.Millisecond, directMsg)
	_, err = client.Get(mockURL)
	assert.Error(t, err, "should have error if reading times out for a previously worked url")
	resp, err = client.Get(mockURL)
	if assert.NoError(t, err, "but should have no error for the second time") {
		u, _ := url.Parse(mockURL)
		time.Sleep(50 * time.Millisecond)
		assertContent(t, resp, detourMsg, "should detour if reading times out")
		assert.True(t, wlTemporarily(u.Host), "should be added to whitelist if reading times out")
	}
}

func TestRemoveFromWhitelist(t *testing.T) {
	defer stopMockServers()
	proxiedURL, proxy := newMockServer(detourMsg)
	proxy.Timeout(200*time.Millisecond, detourMsg)
	mockURL, _ := newMockServer(directMsg)
	client := newClient(proxiedURL, 100*time.Millisecond)

	u, _ := url.Parse(mockURL)
	AddToWl(u.Host, false)
	_, err := client.Get(mockURL)
	if assert.Error(t, err, "should have error if reading times out through detour") {
		assert.False(t, whitelisted(u.Host), "should be removed from whitelist if reading times out through detour")
	}

}

func TestClosing(t *testing.T) {
	DirectAddrCh = make(chan string)
	defer stopMockServers()
	proxiedURL, proxy := newMockServer(detourMsg)
	proxy.Timeout(200*time.Millisecond, detourMsg)
	mockURL, mock := newMockServer(directMsg)
	mock.Msg(directMsg)
	{
		if _, err := newClient(proxiedURL, 100*time.Millisecond).Get(mockURL); err != nil {
			log.Debugf("Unable to send GET request to mock URL: %v", err)
		}
	}
	u, _ := url.Parse(mockURL)
	addr := <-DirectAddrCh
	assert.Equal(t, u.Host, addr, "should get notified when a direct connetion has no error while closing")
}

func TestIranRules(t *testing.T) {
	defer stopMockServers()
	proxiedURL, _ := newMockServer(detourMsg)
	SetCountry("IR")
	u, mock := newMockServer(directMsg)
	client := newClient(proxiedURL, 100*time.Millisecond)

	mock.Raw(iranResp)
	resp, err := client.Get(u)
	if assert.NoError(t, err, "should not error if content hijacked in Iran") {
		assertContent(t, resp, detourMsg, "should detour if content hijacked in Iran")
	}

	// this test can verifies dns hijack detection when run inside Iran,
	// but will only time out and detour when run outside.
	resp, err = client.Get("http://" + iranRedirectAddr)
	if assert.NoError(t, err, "should not error if dns hijacked in Iran") {
		assertContent(t, resp, detourMsg, "should detour if dns hijacked in Iran")
	}
}

func newClient(proxyURL string, timeout time.Duration) *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			Dial: Dialer(func(network, addr string) (net.Conn, error) {
				u, _ := url.Parse(proxyURL)
				return net.Dial("tcp", u.Host)
			})},
		Timeout: timeout,
	}
}
func assertContent(t *testing.T, resp *http.Response, msg string, reason string) {
	b, err := ioutil.ReadAll(resp.Body)
	assert.NoError(t, err, reason)
	assert.Equal(t, msg, string(b), reason)
}
