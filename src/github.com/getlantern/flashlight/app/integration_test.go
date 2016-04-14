package app

import (
	"compress/gzip"
	"crypto/tls"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/http-proxy-lantern"
	"github.com/getlantern/tlsdefaults"
	"github.com/getlantern/waitforserver"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/config"

	"github.com/stretchr/testify/assert"
)

const (
	LocalProxyAddr  = "localhost:18345"
	ProxyServerAddr = "localhost:18346"
	OBFS4ServerAddr = "localhost:18347"

	Content  = "THIS IS SOME STATIC CONTENT FROM THE WEB SERVER"
	Token    = "AF325DF3432FDS"
	KeyFile  = "./proxykey.pem"
	CertFile = "./proxycert.pem"

	Etag        = "X-Lantern-Etag"
	IfNoneMatch = "X-Lantern-If-None-Match"
)

var (
	useOBFS4 = uint32(0)
)

func TestProxying(t *testing.T) {
	config.CloudConfigPollInterval = 100 * time.Millisecond

	// Web server serves known content for testing
	httpAddr, httpsAddr, err := startWebServer(t)
	if !assert.NoError(t, err) {
		return
	}

	// This is the remote proxy server
	err = startProxyServer(t)
	if !assert.NoError(t, err) {
		return
	}

	// This is a fake config server that serves up a config that points at our
	// testing proxy server.
	configAddr, err := startConfigServer(t)
	if !assert.NoError(t, err) {
		return
	}

	// We have to write out a config file so that Lantern doesn't try to use the
	// default config, which would go to some remote proxies that can't talk to
	// our fake config server.
	err = writeConfig(configAddr)
	if !assert.NoError(t, err) {
		return
	}

	// Starts the Lantern App
	err = startApp(t)
	if !assert.NoError(t, err) {
		return
	}

	// Makes a test request
	testRequest(t, httpAddr, httpsAddr)

	// Switch to obfs4, wait for a new config and test request again
	atomic.StoreUint32(&useOBFS4, 1)
	time.Sleep(2 * time.Second)
	testRequest(t, httpAddr, httpsAddr)
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
		Obfs4Addr:    OBFS4ServerAddr,
		Obfs4Dir:     ".",
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

	return waitforserver.WaitForServer("tcp", ProxyServerAddr, 10*time.Second)
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
		obfs4 := atomic.LoadUint32(&useOBFS4) == 1
		version := "1"
		if obfs4 {
			version = "2"
		}

		if req.Header.Get(IfNoneMatch) == version {
			resp.WriteHeader(http.StatusNotModified)
			return
		}

		cfg, err := buildConfig(configAddr, obfs4)
		if err != nil {
			t.Error(err)
			resp.WriteHeader(http.StatusInternalServerError)
			return
		}

		resp.Header().Set(Etag, version)
		resp.WriteHeader(http.StatusOK)

		w := gzip.NewWriter(resp)
		w.Write(cfg)
		w.Close()
	}
}

func writeConfig(configAddr string) error {
	filename := "lantern-9999.99.99.yaml"
	err := os.Remove(filename)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("Unable to delete existing yaml config: %v", err)
	}

	cfg, err := buildConfig(configAddr, false)
	if err != nil {
		return err
	}

	return ioutil.WriteFile(filename, cfg, 0644)
}

func buildConfig(configAddr string, obfs4 bool) ([]byte, error) {
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

	srv := cfg.Client.ChainedServers["fallback-template"]
	srv.AuthToken = Token
	if obfs4 {
		srv.Addr = OBFS4ServerAddr
		srv.PluggableTransport = "obfs4"
		srv.PluggableTransportSettings = map[string]string{
			"iat-mode": "0",
		}

		bridgelineFile, err := ioutil.ReadFile("obfs4_bridgeline.txt")
		if err != nil {
			return nil, fmt.Errorf("Could not read obfs4_bridgeline.txt: %v", err)
		}
		obfs4extract := regexp.MustCompile(".+cert=([^\\s]+).+")
		srv.Cert = string(obfs4extract.FindSubmatch(bridgelineFile)[1])
	} else {
		srv.Addr = ProxyServerAddr

		cert, err := ioutil.ReadFile(CertFile)
		if err != nil {
			return nil, fmt.Errorf("Could not read cert %v", err)
		}
		srv.Cert = string(cert)
	}
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
		"stickyconfig":         false,
		"clear-proxy-settings": false,
		"uiaddr":               "127.0.0.1:16823",
	}

	a := &App{
		ShowUI: false,
		Flags:  flags,
	}
	a.Init()
	go func() {
		err := a.Run()
		assert.NoError(t, err, "Unable to run app")
	}()

	return waitforserver.WaitForServer("tcp", LocalProxyAddr, 10*time.Second)
}

func testRequest(t *testing.T, httpAddr string, httpsAddr string) {
	proxyURL, _ := url.Parse("http://" + LocalProxyAddr)
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyURL(proxyURL),
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
			},
		},
	}

	doRequest(t, client, "http://"+httpAddr)
	doRequest(t, client, "https://"+httpsAddr)
}

func doRequest(t *testing.T, client *http.Client, url string) {
	resp, err := client.Get(url)
	if assert.NoError(t, err, "Unable to GET for "+url) {
		defer resp.Body.Close()
		b, err := ioutil.ReadAll(resp.Body)
		if assert.NoError(t, err, "Unable to read response for "+url) {
			if assert.Equal(t, http.StatusOK, resp.StatusCode, "Bad response status for "+url+": "+string(b)) {
				assert.Equal(t, Content, string(b))
			}
		}
	}
}
