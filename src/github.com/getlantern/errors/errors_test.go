package errors

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

type rawReporter struct {
	err Error
}

func (r *rawReporter) Report(e Error) {
	r.err = e
}

type stringReporter struct {
	buf bytes.Buffer
}

func (r *stringReporter) Report(e Error) {
	fmt.Fprintf(&r.buf, "%+v", string(toJSON(e)))
}

func (r *stringReporter) String() string {
	return r.buf.String()
}

func TestWriteError(t *testing.T) {
	sr := &stringReporter{}
	ReportTo(sr)
	l := NewProxyErrorCollector("my-module", ChainedServer)
	l.Log(io.EOF)
	expected, _ := json.Marshal(struct {
		Module    string `json:"module"`
		Type      string `json:"type"`
		Desc      string `json:"desc"`
		ProxyType string `json:"proxyType"`
	}{
		"my-module",
		"io.EOF",
		"EOF",
		"chained server",
	})
	assert.Equal(t, string(expected), sr.String(), "should log io.EOF")
}

func TestCaptureProxyError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewProxyErrorCollector("my-proxy-module", ChainedServer)
	_, err := net.Dial("tcp", "an.non-existent.domain:80")
	l.Log(err)
	expected := ProxyError{
		BasicError{
			"my-proxy-module",
			"net.DNSError",
			"no such host",
			map[string]string{
				"network": "tcp",
				"domain":  "an.non-existent.domain",
			},
		},
		ChainedServer,
		"dial",
	}
	assert.Equal(t, expected, *(rr.err.(*ProxyError)), "should log http error")
}

func TestCaptureApplicationError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewProxyErrorCollector("application-logic", ChainedServer)
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, _, _ := w.(http.Hijacker).Hijack()
		_ = conn.Close()
	}))
	defer ts.Close()

	_, err := http.Get(ts.URL)
	l.Log(err)
	expected := ProxyError{
		BasicError{
			"application-logic",
			"url.Error",
			"EOF",
			map[string]string{},
		},
		ChainedServer,
		"Get",
	}
	assert.Equal(t, expected, *(rr.err.(*ProxyError)), "should log http error")
}
