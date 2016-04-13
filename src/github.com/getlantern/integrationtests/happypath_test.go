package integrationtests

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/Yawning/obfs4/common/log"
	"github.com/getlantern/http-proxy-lantern"
	"github.com/getlantern/tlsdefaults"
	"github.com/getlantern/waitforserver"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/app"
	"github.com/getlantern/flashlight/config"

	"github.com/stretchr/testify/assert"
)

const (
	LocalProxyAddr  = "localhost:18345"
	ProxyServerAddr = "localhost:18346"

	Content  = "THIS IS SOME STATIC CONTENT FROM THE WEB SERVER"
	Token    = "AF325DF3432FDS"
	KeyFile  = "./key.pem"
	CertFile = "./cert.pem"

	Etag        = "X-Lantern-Etag"
	IfNoneMatch = "X-Lantern-If-None-Match"
)

func TestProxying(t *testing.T) {
	httpAddr, _, err := startWebServer(t)
	if !assert.NoError(t, err) {
		return
	}

	err = startProxyServer(t)
	if !assert.NoError(t, err) {
		return
	}

	configAddr, err := startConfigServer(t)
	if !assert.NoError(t, err) {
		return
	}

	err = startApp(t, configAddr)
	if !assert.NoError(t, err) {
		return
	}

	time.Sleep(1 * time.Minute)
	makeRequest(t, httpAddr)
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
	resp.WriteHeader(http.StatusFound)
	resp.Write([]byte(Content))
}

func startProxyServer(t *testing.T) error {
	s := &httpproxylantern.Server{
		TestingLocal: true,
		Addr:         ProxyServerAddr,
		Token:        Token,
		Keyfile:      KeyFile,
		CertFile:     CertFile,
	}

	go func() {
		err := s.ListenAndServe()
		assert.NoError(t, err, "Proxy server should have been able to listen")
	}()

	return waitforserver.WaitForServer("tcp", ProxyServerAddr, 100*time.Millisecond)
}

func startConfigServer(t *testing.T) (string, error) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", fmt.Errorf("Unable to listen for config server connection: %v", err)
	}
	go func() {
		err := http.Serve(l, http.HandlerFunc(serveConfig(ProxyServerAddr)))
		assert.NoError(t, err, "Unable to serve config")
	}()
	return l.Addr().String(), nil
}

func serveConfig(httpsAddr string) func(http.ResponseWriter, *http.Request) {
	return func(resp http.ResponseWriter, req *http.Request) {
		if "1" == req.Header.Get(IfNoneMatch) {
			resp.WriteHeader(http.StatusNotModified)
			return
		}

		bytes, err := ioutil.ReadFile("./config-template.yaml")
		if err != nil {
			log.Errorf("Could not read config %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		cfg := &config.Config{}
		err = yaml.Unmarshal(bytes, cfg)
		if err != nil {
			log.Errorf("Could not unmarshal config %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		cert, err := ioutil.ReadFile(CertFile)
		if err != nil {
			log.Errorf("Could not read cert %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		srv := cfg.Client.ChainedServers["fallback-template"]
		srv.Addr = httpsAddr
		srv.AuthToken = Token
		srv.Cert = string(cert)
		out, err := yaml.Marshal(cfg)
		if err != nil {
			log.Errorf("Could not marshal config %v", err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}
		resp.Header().Set(Etag, "1")
		resp.WriteHeader(http.StatusFound)
		resp.Write(out)
	}
}

func startApp(t *testing.T, configAddr string) error {
	flags := map[string]interface{}{
		"addr":                 LocalProxyAddr,
		"cloudconfig":          "http://" + configAddr,
		"headless":             true,
		"proxyall":             true,
		"configdir":            ".",
		"stickyconfig":         false,
		"clear-proxy-settings": false,
		"uiaddr":               "127.0.0.1:16823",
	}

	a := &app.App{
		ShowUI: false,
		Flags:  flags,
	}
	a.Init()
	go func() {
		err := a.Run()
		assert.NoError(t, err, "Unable to run app")
	}()

	return waitforserver.WaitForServer("tcp", LocalProxyAddr, 5*time.Second)
}

func makeRequest(t *testing.T, addr string) {
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return net.Dial("tcp", LocalProxyAddr)
			},
		},
	}

	resp, err := client.Get("http://" + addr)
	if assert.NoError(t, err, "Unable to GET") {
		defer resp.Body.Close()
		if assert.Equal(t, http.StatusFound, resp.StatusCode, "Bad response status") {
			b, err := ioutil.ReadAll(resp.Body)
			if assert.NoError(t, err, "Unable to read response") {
				assert.Equal(t, Content, string(b))
			}
		}
	}
}
