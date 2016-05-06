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

type stringReporter struct {
	buf bytes.Buffer
}

func (r *stringReporter) Report(e Error) {
	fmt.Fprintf(&r.buf, "%+v", string(toJSON(e)))
}

func TestWriteError(t *testing.T) {
	sr := &stringReporter{}
	ReportTo(sr)
	l := NewProxyErrorCollector("my-package", ChainedProxy)
	l.Log(io.EOF)
	expected, _ := json.Marshal(struct {
		Package   string `json:"package"`
		Type      string `json:"type"`
		Desc      string `json:"desc"`
		ProxyType string `json:"proxyType"`
	}{
		"my-package",
		"io.EOF",
		"EOF",
		"chained",
	})
	assert.Equal(t, string(expected), sr.buf.String(), "should log io.EOF")
}

type rawReporter struct {
	err Error
}

func (r *rawReporter) Report(e Error) {
	r.err = e
}

func TestCaptureProxyError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewProxyErrorCollector("my-proxy-package", ChainedProxy)
	_, err := net.Dial("tcp", "an.non-existent.domain:80")
	l.Log(err)
	expected := ProxyError{
		BasicError{
			"my-proxy-package",
			"net.DNSError",
			"no such host",
			"dial",
			map[string]string{
				"network": "tcp",
				"domain":  "an.non-existent.domain",
			},
		},
		ChainedProxy,
	}
	assert.Equal(t, expected, *(rr.err.(*ProxyError)), "should log http error")
}

func TestCaptureApplicationError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewProxyErrorCollector("application-logic", ChainedProxy)
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
			"Get",
			map[string]string{},
		},
		ChainedProxy,
	}
	assert.Equal(t, expected, *(rr.err.(*ProxyError)), "should log http error")
}
