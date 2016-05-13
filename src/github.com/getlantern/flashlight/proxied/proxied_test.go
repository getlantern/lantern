package proxied

import (
	"bytes"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"strings"
	"testing"
	"time"

	"github.com/mailgun/oxy/forward"

	"github.com/getlantern/eventual"
	"github.com/getlantern/fronted"

	"github.com/stretchr/testify/assert"
)

// TestChainedAndFrontedHeaders tests to make sure headers are correctly
// copied to the fronted request from the original chained request.
func TestChainedAndFrontedHeaders(t *testing.T) {
	geo := "http://d3u5fqukq7qrhd.cloudfront.net/lookup/198.199.72.101"
	req, err := http.NewRequest("GET", geo, nil)
	if !assert.NoError(t, err) {
		return
	}
	req.Header.Set("Lantern-Fronted-URL", geo)
	req.Header.Set("Accept", "application/x-gzip")
	// Prevents intermediate nodes (domain-fronters) from caching the content
	req.Header.Set("Cache-Control", "no-cache")
	etag := "473892jdfda"
	req.Header.Set("X-Lantern-If-None-Match", etag)

	// Make sure the chained response fails.
	chainedFunc := func(req *http.Request) (*http.Response, error) {
		headers, _ := httputil.DumpRequest(req, false)
		log.Debugf("Got chained request headers:\n%v", string(headers))
		return &http.Response{
			Status:     "503 OK",
			StatusCode: 503,
		}, nil
	}

	frontedHeaders := eventual.NewValue()
	frontedFunc := func(req *http.Request) (*http.Response, error) {
		headers, _ := httputil.DumpRequest(req, false)
		log.Debugf("Got FRONTED request headers:\n%v", string(headers))
		frontedHeaders.Set(req.Header)
		return &http.Response{
			Status:     "200 OK",
			StatusCode: 200,
			Body:       ioutil.NopCloser(bytes.NewBufferString("Fronted")),
		}, nil
	}

	df := &dualFetcher{&chainedAndFronted{parallel: true}}

	df.do(req, chainedFunc, frontedFunc)

	headersVal, ok := frontedHeaders.Get(2 * time.Second)
	if !assert.True(t, ok, "Failed to get fronted headers") {
		return
	}
	headers := headersVal.(http.Header)
	assert.Equal(t, etag, headers.Get("X-Lantern-If-None-Match"))
	assert.Equal(t, "no-cache", headers.Get("Cache-Control"))

	// There should not be a host header here -- the go http client will populate
	// it automatically based on the URL.
	assert.Equal(t, "", headers.Get("Host"))
}

// TestChainedAndFrontedParallel tests to make sure chained and fronted requests
// are both working in parallel.
func TestParallelPreferChained(t *testing.T) {
	doTestChainedAndFronted(t, ParallelPreferChained)
}

func TestChainedThenFronted(t *testing.T) {
	doTestChainedAndFronted(t, ChainedThenFronted)
}

func doTestChainedAndFronted(t *testing.T, build func() http.RoundTripper) {
	fwd, _ := forward.New()

	sleep := 0 * time.Second

	forward := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		log.Debugf("Got request")

		// The sleep can help the other request to complete faster.
		time.Sleep(sleep)
		fwd.ServeHTTP(w, req)
	})

	// that's it! our reverse proxy is ready!
	s := &http.Server{
		Handler: forward,
	}

	log.Debug("Starting server")
	l, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		assert.NoError(t, err, "Unable to listen")
	}
	go s.Serve(l)

	SetProxyAddr(eventual.DefaultGetter(l.Addr().String()))

	fronted.ConfigureForTest(t)

	geo := "http://d3u5fqukq7qrhd.cloudfront.net/lookup/198.199.72.101"
	req, err := http.NewRequest("GET", geo, nil)
	req.Header.Set("Lantern-Fronted-URL", geo)

	assert.NoError(t, err)

	cf := build()
	resp, err := cf.RoundTrip(req)
	assert.NoError(t, err)
	body, err := ioutil.ReadAll(resp.Body)
	assert.NoError(t, err)
	//log.Debugf("Got body: %v", string(body))
	assert.True(t, strings.Contains(string(body), "New York"), "Unexpected response ")
	_ = resp.Body.Close()

	// Now test with a bad cloudfront url that won't resolve and make sure even the
	// delayed req server still gives us the result
	sleep = 2 * time.Second
	bad := "http://48290.cloudfront.net/lookup/198.199.72.101"
	req, err = http.NewRequest("GET", geo, nil)
	req.Header.Set("Lantern-Fronted-URL", bad)
	assert.NoError(t, err)
	cf = build()
	resp, err = cf.RoundTrip(req)
	assert.NoError(t, err)
	log.Debugf("Got response in test")
	body, err = ioutil.ReadAll(resp.Body)
	assert.NoError(t, err)
	assert.True(t, strings.Contains(string(body), "New York"), "Unexpected response ")
	_ = resp.Body.Close()

	// Now give the bad url to the req server and make sure we still get the corret
	// result from the fronted server.
	log.Debugf("Running test with bad URL in the req server")
	bad = "http://48290.cloudfront.net/lookup/198.199.72.101"
	req, err = http.NewRequest("GET", bad, nil)
	req.Header.Set("Lantern-Fronted-URL", geo)
	assert.NoError(t, err)
	cf = build()
	resp, err = cf.RoundTrip(req)
	if assert.NoError(t, err) {
		if assert.Equal(t, 200, resp.StatusCode) {
			body, err = ioutil.ReadAll(resp.Body)
			if assert.NoError(t, err) {
				assert.True(t, strings.Contains(string(body), "New York"), "Unexpected response "+string(body))
			}
		}
		_ = resp.Body.Close()
	}
}
