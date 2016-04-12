package integrationtests

import (
	"fmt"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/http-proxy-lantern"
	"github.com/getlantern/tlsdefaults"
	"github.com/getlantern/waitforserver"

	"github.com/stretchr/testify/assert"
)

const (
	CONTENT = "THIS IS SOME STATIC CONTENT FROM THE WEB SERVER"
	TOKEN   = "AF325DF3432FDS"
)

func TestProxying(t *testing.T) {
	httpAddr, httpsAddr, err := startWebServer(t)
	if !assert.NoError(t, err) {
		return
	}

	proxyServerAddr := "localhost:18349"
	s := &httpproxylantern.Server{
		Addr:  proxyServerAddr,
		Token: TOKEN,
	}

	go func() {
		err := s.ListenAndServe()
		assert.NoError(t, err, "Proxy server should have been able to listen")
	}()

	if !assert.NoError(t, waitforserver.WaitForServer("tcp", proxyServerAddr, 100*time.Millisecond), "Proxy Server didn't come up") {
		return
	}
}

func startWebServer(t *testing.T) (string, string, error) {
	lh, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", "", fmt.Errorf("Unable to listen for HTTP connections: %v", err)
	}
	ls, err := tlsdefaults.Listen("localhost:0", "happypk.pem", "happycert.pem")
	if err != nil {
		return "", "", fmt.Errorf("Unable to listen for HTTPS connections: %v", err)
	}
	go func() {
		err := http.Serve(lh, http.HandlerFunc(serveContent))
		assert.NoError(t, err, "Unable to serve HTTP")
	}()
	go func() {
		err := http.Serve(ls, http.HandlerFunc(serveContent))
		assert.NoError(t, err, "Unable to serve HTTPS")
	}()
	return lh.Addr().String(), ls.Addr().String(), nil
}

func serveContent(resp http.ResponseWriter, req *http.Request) {
	resp.WriteHeader(200)
	resp.Write([]byte(CONTENT))
}
