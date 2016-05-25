package pro

import (
	"bytes"
	"errors"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"sync"

	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
)

const (
	proAPIHost = "api.getiantem.org"
)

var (
	log      = golog.LoggerFor("flashlight.logging")
	clientMu sync.RWMutex
	httpC    *http.Client
)

type proxyTransport struct {
	// Satisfies http.RoundTripper
}

func (pt *proxyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	clientMu.RLock()
	defer clientMu.RUnlock()

	if httpC == nil {
		return nil, errors.New("Missing client.")
	}

	if req.Method == "OPTIONS" {
		// No need to proxy the OPTIONS request.
		res := &http.Response{
			StatusCode: http.StatusOK,
			Header: http.Header{
				"Connection":                   {"keep-alive"},
				"Access-Control-Allow-Methods": {"GET, POST"},
				"Access-Control-Allow-Origin":  {req.Header.Get("Origin")},
				"Access-Control-Allow-Headers": {req.Header.Get("Access-Control-Request-Headers")},
				"Via": {"Lantern Client"},
			},
			Body: ioutil.NopCloser(bytes.NewBuffer([]byte("preflight complete"))),
		}
		return res, nil
	}
	return httpC.Do(req)
}

var proxyHandler = &httputil.ReverseProxy{
	Transport: &proxyTransport{},
	Director: func(r *http.Request) {
		r.URL.Scheme = "https"
		r.URL.Host = proAPIHost
		r.Host = r.URL.Host
		r.RequestURI = ""                                   // http: Request.RequestURI can't be set in client requests.
		r.Header.Set("Lantern-Fronted-URL", r.URL.String()) // This is required by NewChainedAndFronted.
		r.Header.Set("Access-Control-Allow-Headers", "X-Lantern-Device-Id, X-Lantern-Pro-Token, X-Lantern-User-Id")
	},
}

func Configure(cloudConfigCA string) {
	clientMu.Lock()
	defer clientMu.Unlock()

	rt, err := proxied.ChainedPersistent(cloudConfigCA)
	if err != nil {
		log.Errorf("Could not create HTTP client: %v", err)
		return
	}

	httpC = &http.Client{Transport: rt}
}

func InitProxy(addr string) error {
	return http.ListenAndServe(addr, proxyHandler)
}
