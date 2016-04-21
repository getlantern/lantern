package pro

import (
	"bytes"
	"errors"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"sync"

	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight/util"
)

const (
	proAPIHost = "quiet-island-5559.herokuapp.com"
)

var (
	cf   util.HTTPFetcher
	cfMu sync.RWMutex
)

type proxyTransport struct {
	// Satisfies http.RoundTripper
}

func (pt *proxyTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	cfMu.RLock()
	defer cfMu.RUnlock()
	if cf == nil {
		return nil, errors.New("Missing client")
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
	return cf.Do(req)
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

func Configure(proxyAddrFN eventual.Getter) {
	cfMu.Lock()
	defer cfMu.Unlock()
	cf = util.NewChainedAndFronted(proxyAddrFN)
}

func InitProxy(addr string) error {
	return http.ListenAndServe(addr, proxyHandler)
}
