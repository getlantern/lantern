package errlog

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
	l := ErrorLoggerFor("my-package")
	l.Log(io.EOF)
	expected, _ := json.Marshal(struct {
		Package string `json:"package"`
		Type    string `json:"type"`
		Desc    string `json:"desc"`
		*UserLocale
	}{
		"my-package",
		"io.EOF",
		"EOF",
		userLocale,
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
	l := ErrorLoggerFor("my-proxy-package")
	err := errors.New("any error")
	l.Log(err)
	expected := &Error{
		Source:     err,
		GoPackage:  "my-proxy-package",
		GoType:     "*errors.errorString",
		Desc:       "any error",
		Op:         "",
		Extra:      map[string]string{},
		UserLocale: userLocale,
	}
	assert.Equal(t, expected, rr.err, "should log errors created by errors.New")

	l.Log(fmt.Errorf("any error"))
	assert.Equal(t, expected, rr.err, "should log errors created by fmt.Errorf")
}

func TestStructuredError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := ErrorLoggerFor("my-proxy-package")
	source := errors.New("any error")
	err := &Error{
		Source:    source,
		GoPackage: "specified package",
		GoType:    "specified type",
		Desc:      "specified desc",
		Op:        "specified op",
		Extra: map[string]string{
			"extra1": "specified extra1",
		},
	}
	l.Log(err)
	expected := &Error{
		Source:     source,
		GoPackage:  err.GoPackage,
		GoType:     err.GoType,
		Desc:       err.Desc,
		Op:         err.Op,
		Extra:      err.Extra,
		UserLocale: userLocale,
	}
	assert.Equal(t, expected, rr.err, "should log structured errors")
}

func TestCaptureError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := ErrorLoggerFor("my-proxy-package")
	_, err := net.Dial("tcp", "an.non-existent.domain:80")
	l.Log(err)
	expected := &Error{
		Source:    err,
		GoPackage: "my-proxy-package",
		GoType:    "net.DNSError",
		Desc:      "no such host",
		Op:        "dial",
		Extra: map[string]string{
			"network": "tcp",
			"domain":  "an.non-existent.domain",
		},
		UserLocale: userLocale,
	}
	assert.Equal(t, expected, rr.err, "should log dial error")
}

func TestCaptureApplicationError(t *testing.T) {
	rr := &rawReporter{}
	ReportTo(rr)
	l := ErrorLoggerFor("application-logic")
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, _, _ := w.(http.Hijacker).Hijack()
		_ = conn.Close()
	}))
	defer ts.Close()

	_, err := http.Get(ts.URL)
	l.Log(err)
	expected := &Error{
		Source:     err,
		GoPackage:  "application-logic",
		GoType:     "url.Error",
		Desc:       "EOF",
		Op:         "Get",
		Extra:      map[string]string{},
		UserLocale: userLocale,
	}
	assert.Equal(t, expected, rr.err, "should log http error")
}
