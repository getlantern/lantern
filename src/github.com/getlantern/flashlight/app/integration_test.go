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
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/http-proxy-lantern"
	"github.com/getlantern/tlsdefaults"
	"github.com/getlantern/waitforserver"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/client"
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
	//config.CloudConfigPollInterval = 100 * time.Millisecond

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
	err = writeConfig()
	if !assert.NoError(t, err) {
		return
	}

	// Starts the Lantern App
	err = startApp(t, configAddr)
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
	s := &proxy.Proxy{
		TestingLocal: true,
		Addr:         ProxyServerAddr,
		Obfs4Addr:    OBFS4ServerAddr,
		Obfs4Dir:     ".",
		Token:        Token,
		KeyFile:      KeyFile,
		CertFile:     CertFile,
		IdleClose:    30,
		HTTPS:        true,
	}

	go func() {
		err := s.ListenAndServe()
		assert.NoError(t, err, "Proxy server should have been able to listen")
	}()

	err := waitforserver.WaitForServer("tcp", ProxyServerAddr, 10*time.Second)
	if err != nil {
		return err
	}

	// Wait for cert file to show up
	var statErr error
	for i := 0; i < 400; i++ {
		_, statErr = os.Stat(CertFile)
		if statErr != nil {
			time.Sleep(25 * time.Millisecond)
		}
	}
	return statErr
}

func startConfigServer(t *testing.T) (string, error) {
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", fmt.Errorf("Unable to listen for config server connection: %v", err)
	}
	go func() {
		err := http.Serve(l, http.HandlerFunc(serveConfig(t)))
		assert.NoError(t, err, "Unable to serve config")
	}()
	return l.Addr().String(), nil
}

func serveConfig(t *testing.T) func(http.ResponseWriter, *http.Request) {
	return func(resp http.ResponseWriter, req *http.Request) {
		log.Debugf("Reading request path: %v", req.URL.String())
		if strings.Contains(req.URL.String(), "global") {
			writeGlobalConfig(t, resp, req)
		} else if strings.Contains(req.URL.String(), "prox") {
			writeProxyConfig(t, resp, req)
		} else {
			log.Errorf("Not requesting global or proxies in %v", req.URL.String())
			resp.WriteHeader(http.StatusBadRequest)
		}
	}
}

func writeGlobalConfig(t *testing.T, resp http.ResponseWriter, req *http.Request) {
	log.Debug("Writing global config")
	obfs4 := atomic.LoadUint32(&useOBFS4) == 1
	version := "1"
	if obfs4 {
		version = "2"
	}

	if req.Header.Get(IfNoneMatch) == version {
		resp.WriteHeader(http.StatusNotModified)
		return
	}

	cfg, err := buildGlobal()
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

func writeProxyConfig(t *testing.T, resp http.ResponseWriter, req *http.Request) {
	log.Debug("Writing proxy config")
	obfs4 := atomic.LoadUint32(&useOBFS4) == 1
	version := "1"
	if obfs4 {
		version = "2"
	}

	if req.Header.Get(IfNoneMatch) == version {
		resp.WriteHeader(http.StatusNotModified)
		return
	}

	cfg, err := buildProxies(obfs4)
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

func writeConfig() error {
	filename := "proxies.yaml"
	err := os.Remove(filename)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("Unable to delete existing yaml config: %v", err)
	}

	cfg, err := buildProxies(false)
	if err != nil {
		return err
	}

	return ioutil.WriteFile(filename, cfg, 0644)
}

func buildProxies(obfs4 bool) ([]byte, error) {
	bytes, err := ioutil.ReadFile("./proxies-template.yaml")
	if err != nil {
		return nil, fmt.Errorf("Could not read config %v", err)
	}

	cfg := make(map[string]*client.ChainedServerInfo)
	err = yaml.Unmarshal(bytes, cfg)
	if err != nil {
		return nil, fmt.Errorf("Could not unmarshal config %v", err)
	}

	srv := cfg["fallback-template"]
	srv.AuthToken = Token
	if obfs4 {
		srv.Addr = OBFS4ServerAddr
		srv.PluggableTransport = "obfs4"
		srv.PluggableTransportSettings = map[string]string{
			"iat-mode": "0",
		}

		bridgelineFile, err2 := ioutil.ReadFile("obfs4_bridgeline.txt")
		if err2 != nil {
			return nil, fmt.Errorf("Could not read obfs4_bridgeline.txt: %v", err2)
		}
		obfs4extract := regexp.MustCompile(".+cert=([^\\s]+).+")
		srv.Cert = string(obfs4extract.FindSubmatch(bridgelineFile)[1])
	} else {
		srv.Addr = ProxyServerAddr

		cert, err2 := ioutil.ReadFile(CertFile)
		if err2 != nil {
			return nil, fmt.Errorf("Could not read cert %v", err2)
		}
		srv.Cert = string(cert)
	}
	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, fmt.Errorf("Could not marshal config %v", err)
	}

	return out, nil
}

func buildGlobal() ([]byte, error) {
	bytes, err := ioutil.ReadFile("./global-template.yaml")
	if err != nil {
		return nil, fmt.Errorf("Could not read config %v", err)
	}

	cfg := &config.Global{}
	err = yaml.Unmarshal(bytes, cfg)
	if err != nil {
		return nil, fmt.Errorf("Could not unmarshal config %v", err)
	}

	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, fmt.Errorf("Could not marshal config %v", err)
	}

	return out, nil
}

func startApp(t *testing.T, configAddr string) error {
	configURL := "http://" + configAddr
	flags := map[string]interface{}{
		"cloudconfig":          configURL,
		"frontedconfig":        configURL,
		"addr":                 LocalProxyAddr,
		"headless":             true,
		"proxyall":             true,
		"configdir":            ".",
		"stickyconfig":         false,
		"clear-proxy-settings": false,
		"readableconfig":       true,
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
