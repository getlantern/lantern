package errors

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

type rawReporter struct {
	err *Error
}

func (r *rawReporter) Report(e *Error) {
	r.err = e
}

func TestAnonymousError(t *testing.T) {
	rr := &rawReporter{}
	Initialize("", rr, false)
	New("any error").Report()
	expected := &Error{
		Package: "github.com/getlantern/errors",
		Func:    "TestAnonymousError",
		GoType:  "errors.Error",
		Desc:    "any error",
	}
	assert.Equal(t, expected.Error(), rr.err.Error(), "should log errors created by New()")

	Wrap(fmt.Errorf("any error")).Report()
	expected.GoType = "*errors.errorString"
	assert.Equal(t, expected.Error(), rr.err.Error(), "should log errors created by Wrap()")
}

func TestWrapNil(t *testing.T) {
	assert.Nil(t, Wrap(nil), "should not wrap nil")
}

func TestWrapAlreadyWrapped(t *testing.T) {
	e := New("any error")
	assert.Equal(t, e, Wrap(e), "should not wrap already wrapped error")
}

func TestWithFields(t *testing.T) {
	rr := &rawReporter{}
	Initialize("", rr, false)
	e := Wrap(errors.New("any error")).
		WithOp("test").
		ProxyType(NoProxy).
		ProxyAddr("a.b.c.d:80").
		OriginSite("www.google.com:443").
		WithLocale().
		With("foo", "bar")
	e.Report()
	assert.NotEqual(t, rr.err.FileLine, rr.err.ReportFileLine, "should log all fields")
	expected := "any error Op=test ProxyType=no_proxy ProxyAddr=a.b.c.d:80 OriginSite=www.google.com:443 TimeZone=CST Language=C foo=bar Func=TestWithFields GoType=*errors.errorString Package=github.com/getlantern/errors"
	assert.Equal(t, expected, rr.err.Error(), "should log all fields")
}

func TestCaptureError(t *testing.T) {
	rr := &rawReporter{}
	Initialize("", rr, false)
	_, e := net.Dial("tcp", "an.non-existent.domain:80")
	err := Wrap(e)
	err.Report()
	expected := "no such host Op=dial network=tcp domain=an.non-existent.domain Func=TestCaptureError GoType=net.DNSError Package=github.com/getlantern/errors"
	assert.Contains(t, rr.err.Error(), expected, "should log dial error")
}

func TestCaptureHTTPError(t *testing.T) {
	rr := &rawReporter{}
	Initialize("", rr, false)
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, _, _ := w.(http.Hijacker).Hijack()
		_ = conn.Close()
	}))
	defer ts.Close()

	req, _ := http.NewRequest("GET", ts.URL, nil)
	client := &http.Client{}
	_, e := client.Do(req)
	err := Wrap(e).Request(req)
	err.Report()
	expected := &Error{
		Package: "github.com/getlantern/errors",
		Func:    "TestCaptureHTTPError",
		GoType:  "url.Error",
		Desc:    "EOF",
		Op:      "Get",
		HTTPRequest: &HTTPRequest{
			Method:    "GET",
			Scheme:    "http",
			Protocol:  "HTTP/1.1",
			HostInURL: ts.URL[7:],
			Host:      ts.URL[7:],
		},
	}
	assert.Equal(t, expected.Error(), rr.err.Error(), "should log http error")
}
