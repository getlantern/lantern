package integrationtests

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"os"
	"testing"
	"time"

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
	KeyFile  = "./proxykey.pem"
	CertFile = "./proxycert.pem"

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

	err = writeConfig(configAddr)
	if !assert.NoError(t, err) {
		return
	}

	err = startApp(t)
	if !assert.NoError(t, err) {
		return
	}

	makeRequest(t, httpAddr)
}

func startWebServer(t *testing.T) (string, string, error) {
	lh, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", "", fmt.Errorf("Unable to listen for HTTP connections: %v", err)
	}
	ls, err := tlsdefaults.Listen("localhost:0", "webkey.pem", "webcert.pem")
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
	resp.WriteHeader(http.StatusOK)
	resp.Write([]byte(Content))
}

func startProxyServer(t *testing.T) error {
	s := &httpproxylantern.Server{
		TestingLocal: true,
		Addr:         ProxyServerAddr,
		Token:        Token,
		Keyfile:      KeyFile,
		CertFile:     CertFile,
		IdleClose:    30,
		HTTPS:        true,
	}

	go func() {
		err := s.ListenAndServe()
		assert.NoError(t, err, "Proxy server should have been able to listen")
	}()

	return waitforserver.WaitForServer("tcp", ProxyServerAddr, 1*time.Second)
}

func startConfigServer(t *testing.T) (string, error) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", fmt.Errorf("Unable to listen for config server connection: %v", err)
	}
	configAddr := l.Addr().String()
	go func() {
		err := http.Serve(l, http.HandlerFunc(serveConfig(t, configAddr)))
		assert.NoError(t, err, "Unable to serve config")
	}()
	return configAddr, nil
}

func serveConfig(t *testing.T, configAddr string) func(http.ResponseWriter, *http.Request) {
	return func(resp http.ResponseWriter, req *http.Request) {
		if "1" == req.Header.Get(IfNoneMatch) {
			resp.WriteHeader(http.StatusNotModified)
			return
		}

		cfg, err := buildConfig(configAddr)
		if err != nil {
			t.Error(err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		resp.Header().Set(Etag, "1")
		resp.WriteHeader(http.StatusOK)
		resp.Write(cfg)
	}
}

func writeConfig(configAddr string) error {
	filename := "lantern-9999.99.99.yaml"
	err := os.Remove(filename)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("Unable to delete existing yaml config: %v", err)
	}

	cfg, err := buildConfig(configAddr)
	if err != nil {
		return err
	}

	return ioutil.WriteFile(filename, cfg, 0644)
}

func buildConfig(configAddr string) ([]byte, error) {
	bytes, err := ioutil.ReadFile("./config-template.yaml")
	if err != nil {
		return nil, fmt.Errorf("Could not read config %v", err)
	}

	cfg := &config.Config{}
	err = yaml.Unmarshal(bytes, cfg)
	if err != nil {
		return nil, fmt.Errorf("Could not unmarshal config %v", err)
	}
	cfg.CloudConfig = "http://" + configAddr
	cfg.FrontedCloudConfig = cfg.CloudConfig

	cert, err := ioutil.ReadFile(CertFile)
	if err != nil {
		return nil, fmt.Errorf("Could not read cert %v", err)
	}

	srv := cfg.Client.ChainedServers["fallback-template"]
	srv.Addr = ProxyServerAddr
	srv.AuthToken = Token
	srv.Cert = string(cert)
	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, fmt.Errorf("Could not marshal config %v", err)
	}

	return out, nil
}

func startApp(t *testing.T) error {
	flags := map[string]interface{}{
		"addr":                 LocalProxyAddr,
		"headless":             true,
		"proxyall":             true,
		"configdir":            ".",
		"stickyconfig":         true,
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
	proxyURL, _ := url.Parse("http://" + LocalProxyAddr)
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyURL(proxyURL),
		},
	}

	resp, err := client.Get("http://" + addr)
	if assert.NoError(t, err, "Unable to GET") {
		defer resp.Body.Close()
		b, err := ioutil.ReadAll(resp.Body)
		if assert.NoError(t, err, "Unable to read response") {
			if assert.Equal(t, http.StatusOK, resp.StatusCode, "Bad response status: "+string(b)) {
				assert.Equal(t, Content, string(b))
			}
		}
	}
}
