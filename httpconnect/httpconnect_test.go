package httpconnect

import (
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/getlantern/http-proxy/filters"
	"github.com/stretchr/testify/assert"
)

func TestFilterTunnelPorts(t *testing.T) {
	server := httptest.NewServer(filters.Join(
		New(&Options{AllowedPorts: []int{443, 8080}}),
		filters.Adapt(http.NotFoundHandler())))
	defer server.Close()
	u, _ := url.Parse(server.URL)
	client := http.Client{Transport: &http.Transport{
		Dial: func(network, addr string) (net.Conn, error) {
			return net.Dial("tcp", u.Host)
		},
	}}

	req, _ := http.NewRequest("CONNECT", "http://site.com", nil)
	resp, _ := client.Do(req)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusBadRequest, resp.StatusCode, "CONNECT request without port should fail with 400")

	req, _ = http.NewRequest("CONNECT", "http://site.com:", nil)
	resp, _ = client.Do(req)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusBadRequest, resp.StatusCode, "CONNECT request without port should fail with 400")

	req, _ = http.NewRequest("CONNECT", "http://site.com:abc", nil)
	resp, _ = client.Do(req)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusBadRequest, resp.StatusCode, "CONNECT request without non-integer port should fail with 400")

	req, _ = http.NewRequest("CONNECT", "http://site.com:443", nil)
	resp, _ = client.Do(req)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode, "CONNECT request to allowed port should succeed")

	req, _ = http.NewRequest("CONNECT", "http://site.com:8080", nil)
	resp, _ = client.Do(req)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusOK, resp.StatusCode, "CONNECT request to allowed port should succeed")

	req, _ = http.NewRequest("CONNECT", "http://site.com:8081", nil)
	resp, _ = client.Do(req)
	_ = resp.Body.Close()
	assert.Equal(t, http.StatusForbidden, resp.StatusCode, "CONNECT request to disallowed port should fail with 403")
}
