package detour

import (
	"math/rand"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
	w "github.com/getlantern/waitforserver"
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

func detour(network, addr string) (net.Conn, error) {
	return net.Dial("tcp", ":12307")
}

func TestDetour(t *testing.T) {
	startMockServers(t)
	defer stopMockServers()

	err := w.WaitForServer("tcp", ":12306", 2*time.Second)
	assert.NoError(t, err, "server not started")
	err = w.WaitForServer("tcp", ":12307", 2*time.Second)
	assert.NoError(t, err, "server not started")
	_, err = http.Get(closeURL)
	if assert.Error(t, err, "should error") {
		assert.Equal(t, err.(*url.Error).Err.Error(), "EOF", "should be EOF")
	}
	SetDetourDialer(detour)
	client := &http.Client{Transport: &http.Transport{Dial: Dial}}
	_, err = client.Get(closeURL)
	assert.NoError(t, err, "should detour")
}
