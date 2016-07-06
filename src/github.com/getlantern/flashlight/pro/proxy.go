package pro

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"strings"

	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
)

const (
	proAPIHost    = "api.getiantem.org"
	proAPIDDFHost = "d2n32kma9hyo9f.cloudfront.net"
)

var (
	log        = golog.LoggerFor("flashlight.pro")
	httpClient = &http.Client{Transport: proxied.ParallelPreferChained()}
)

type proxyTransport struct {
	// Satisfies http.RoundTripper
}

func (pt *proxyTransport) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	origin := req.Header.Get("Origin")
	if req.Method == "OPTIONS" {
		// No need to proxy the OPTIONS request.
		resp = &http.Response{
			StatusCode: http.StatusOK,
			Header: http.Header{
				"Connection":                   {"keep-alive"},
				"Access-Control-Allow-Methods": {"GET, POST"},
				"Access-Control-Allow-Headers": {req.Header.Get("Access-Control-Request-Headers")},
				"Via": {"Lantern Client"},
			},
			Body: ioutil.NopCloser(strings.NewReader("preflight complete")),
		}
	} else {
		// Workaround for https://github.com/getlantern/pro-server/issues/192
		req.Header.Del("Origin")
		resp, err = httpClient.Do(req)
		if err != nil {
			log.Errorf("Could not issue HTTP request? %v", err)
			return
		}
	}
	resp.Header.Set("Access-Control-Allow-Origin", origin)
	return
}

var proxyHandler = &httputil.ReverseProxy{
	Transport: &proxyTransport{},
	Director: func(r *http.Request) {
		r.URL.Scheme = "https"
		r.URL.Host = proAPIHost
		r.Host = r.URL.Host
		r.RequestURI = "" // http: Request.RequestURI can't be set in client requests.
		r.Header.Set("Lantern-Fronted-URL", fmt.Sprintf("http://%s%s", proAPIDDFHost, r.URL.Path))
		r.Header.Set("Access-Control-Allow-Headers", "X-Lantern-Device-Id, X-Lantern-Pro-Token, X-Lantern-User-Id")
	},
}

// InitProxy starts the proxy listening on the specified host and port.
func InitProxy(addr string) error {
	return http.ListenAndServe(addr, proxyHandler)
}
