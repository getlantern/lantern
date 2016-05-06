package errors

import (
	"bytes"
	"encoding/json"
	"errors"
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

func (r *stringReporter) Report(e *Error) {
	fmt.Fprintf(&r.buf, "%+v", string(toJSON(e)))
}

func TestWriteErrorAsJSON(t *testing.T) {
	sr := &stringReporter{}
	ReportTo(sr)
	l := NewErrorCollector("my-package")
	l.Log(io.EOF)
	expected, _ := json.Marshal(struct {
		Package string `json:"package"`
		Type    string `json:"type"`
		Desc    string `json:"desc"`
		*systemInfo
	}{
		"my-package",
		"io.EOF",
		"EOF",
		l.systemInfo,
	})
	assert.Equal(t, string(expected), sr.buf.String(), "should write io.EOF as expected JSON")
}

type rawReporter struct {
	err *Error
}

func (r *rawReporter) Report(e *Error) {
	r.err = e
}

func TestAnonymousError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewErrorCollector("my-proxy-package")
	l.Log(errors.New("any error"))
	expected := Error{
		"my-proxy-package",
		"*errors.errorString",
		"any error",
		"",
		map[string]string{},
		l.systemInfo,
		nil,
		nil,
		nil,
	}
	assert.Equal(t, expected, *rr.err, "should log errors created by errors.New")

	l.Log(fmt.Errorf("any error"))
	assert.Equal(t, expected, *rr.err, "should log errors created by fmt.Errorf")
}

func TestCaptureError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewErrorCollector("my-proxy-package")
	_, err := net.Dial("tcp", "an.non-existent.domain:80")
	l.Log(err)
	expected := Error{
		"my-proxy-package",
		"net.DNSError",
		"no such host",
		"dial",
		map[string]string{
			"network": "tcp",
			"domain":  "an.non-existent.domain",
		},
		l.systemInfo,
		nil,
		nil,
		nil,
	}
	assert.Equal(t, expected, *rr.err, "should log http error")
}

func TestCaptureApplicationError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := NewErrorCollector("application-logic")
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, _, _ := w.(http.Hijacker).Hijack()
		_ = conn.Close()
	}))
	defer ts.Close()

	_, err := http.Get(ts.URL)
	l.Log(err)
	expected := Error{
		"application-logic",
		"url.Error",
		"EOF",
		"Get",
		map[string]string{},
		l.systemInfo,
		nil,
		nil,
		nil,
	}
	assert.Equal(t, expected, *rr.err, "should log application error")
}
