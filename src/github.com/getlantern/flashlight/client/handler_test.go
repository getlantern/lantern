package client

/*import (
	"io/ioutil"
	"net"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRespondBadGateway(t *testing.T) {
	proxy := Client{Addr: "localhost:4545"}
	go func() {
		assert.NoError(t, proxy.ListenAndServe(func() {}), "should be able to listen")
	}()
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return net.Dial(network, "127.0.0.1:4545")
			},
		},
	}
	req, err := http.NewRequest("GET", "http://asdfasdfnonexist.com", nil)
	assert.NoError(t, err, "should be able to listen")
	resp, err := client.Do(req)
	if !assert.NoError(t, err, "should be able to listen") {
		return
	}
	assert.Equal(t, http.StatusBadGateway, resp.StatusCode, "should return bad gateway")
	defer func() {
		assert.NoError(t, resp.Body.Close(), "should be able to close body")
	}()

	body, err := ioutil.ReadAll(resp.Body)
	if assert.NoError(t, err, "should be able to listen") {
		assert.Equal(t, "", body, "should return bad gateway")
	}
}*/
