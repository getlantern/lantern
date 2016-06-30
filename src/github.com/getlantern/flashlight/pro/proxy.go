package pro

import (
	"errors"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"strings"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
)

const (
	proAPIHost = "api.getiantem.org"
)

var (
	log        = golog.LoggerFor("flashlight.pro")
	httpClient = eventual.NewValue()
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
		client, resolved := httpClient.Get(60 * time.Second)
		if !resolved {
			log.Error("Trying to proxy pro before we have a client")
			return nil, errors.New("Missing client.")
		}
		// Workaround for https://github.com/getlantern/pro-server/issues/192
		req.Header.Del("Origin")
		resp, err = client.(*http.Client).Do(req)
		if err != nil {
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
		r.RequestURI = ""                                   // http: Request.RequestURI can't be set in client requests.
		r.Header.Set("Lantern-Fronted-URL", r.URL.String()) // This is required by NewChainedAndFronted.
		r.Header.Set("Access-Control-Allow-Headers", "X-Lantern-Device-Id, X-Lantern-Pro-Token, X-Lantern-User-Id")
	},
}

// Configure sets the CA to use for the cloud config.
func Configure(cloudConfigCA string) {
	rt, err := proxied.ChainedPersistent(cloudConfigCA)
	if err != nil {
		log.Errorf("Could not create HTTP client: %v", err)
		return
	}

	log.Debug("Setting http client")
	httpClient.Set(&http.Client{Transport: rt})
}

// InitProxy starts the proxy listening on the specified host and port.
func InitProxy(addr string) error {
	return http.ListenAndServe(addr, proxyHandler)
}
