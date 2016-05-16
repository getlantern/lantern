/*
Package errors defines error types used across Lantern project.
  // initialize globally
  errors.Initialize("appVersion", myErrorReporter, true)
  ...
  if n, err := Foo(); err != nil {
    errors.Wrap(err).Report() // or simply errors.Report(err)
  }

Wrap() method will try as much as possible to extract details from the error
passed in, if it's errors defined in Go standard library. For application
defined error type, at least the Go type name and what err.Error() returns will
be recorded.

Extra fields can be chained in any order, at any time.

  func Connect(addr string) *Error {
  	//...
    return errors.New("some error").ProxyAddr(addr).
	  WithOp("connect").With("some_counter", 1)
  }
  ...
  req *http.Request = ...
  if err := Connect(); err != nil {
	err.Request(req).With("proxy_all", true).Report()
  }

If logging=true when calling Initialize(), Report() will get a logger using
golog.LoggerFor("<package-name-in-which-the-error-is-created">) and call its
Error() method.

It's the caller's responsibility to avoid race condition accessing same error
instance from multiple goroutines.
*/
package errors

import (
	"bufio"
	"bytes"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/textproto"
	"net/url"
	"os"
	"os/exec"
	"reflect"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode"

	"github.com/getlantern/golog"
	localeDetector "github.com/getlantern/jibber_jabber"
	osversion "github.com/getlantern/osversion"
	"github.com/getlantern/stack"
)

var (
	curDirector *director
)

func init() {
	Initialize("", nullReporter{}, true)
}

// Initialize initializes the package globally
func Initialize(appVersion string, r Reporter, enableLogging bool) {
	curDirector = newDirector(appVersion, r, enableLogging)
}

// director glues things together without place them in package namespace.
type director struct {
	si      *SystemInfo
	r       Reporter
	logging bool
}

func newDirector(appVersion string, r Reporter, logging bool) *director {
	osVersion, _ := osversion.GetHumanReadable()
	si := &SystemInfo{
		OSType:     runtime.GOOS,
		OSArch:     runtime.GOARCH,
		OSVersion:  osVersion,
		GoVersion:  runtime.Version(),
		AppVersion: appVersion,
	}
	return &director{si, r, logging}
}

func (d *director) report(e *Error) {
	e.ReportTS = time.Now()
	caller := stack.Caller(2)
	e.ReportFileLine = fmt.Sprintf("%+v", caller)
	e.ReportStack = stack.Trace().TrimBelow(caller).TrimRuntime()
	e.SystemInfo = d.si

	d.r.Report(e)
	if d.logging {
		var pkg = fmt.Sprintf("%k", caller)
		golog.LoggerFor(pkg).ErrorSkipFrames(e.Error(), 3)
	}
}

// Reporter is an interface callers should implement to report captured errors.
type Reporter interface {
	// Report should not reference the Error object passed in after the
	// function returns. Do a deep copy if you want to alter or store it.
	Report(*Error)
}

type nullReporter struct{}

func (l nullReporter) Report(*Error) {}

// New creates an Error with supplied description
func New(s string) (e *Error) {
	e = &Error{
		GoType: "errors.Error",
		Desc:   s,
		TS:     time.Now(),
	}
	e.attachStack(2)
	return
}

// Wrap creates an Error based on the information in an error instance.  It
// returns nil if the error passed in is nil, so we can simply call
// errors.Wrap(s.l.Close()) regardless there's an error or not. If the error is
// already wrapped, it is returned as is.
func Wrap(err error) *Error {
	return wrapSkipFrames(err, 1)
}

// Report is a shortcut for Wrap(err).Report()
func Report(err error) {
	wrapSkipFrames(err, 1).Report()
}

func wrapSkipFrames(err error, skip int) *Error {
	if err == nil {
		return nil
	}
	if e, ok := err.(*Error); ok {
		return e
	}
	e := &Error{
		Source: err,
		TS:     time.Now(),
	}
	// always skip [Wrap, attachStack]
	e.attachStack(2 + skip)
	e.applyDefaults()
	return e
}

// Error wraps system and application defined errors in unified structure for
// reporting and logging. It's not meant to be created directly. User New(),
// Wrap() and Report() instead.
type Error struct {
	// Source captures the underlying error that's wrapped by this Error
	Source error `json:"-"`
	// Stack is caller's stack when Error is created
	Stack stack.CallStack `json:"-"`
	// TS is the timestamp when Error is created
	TS time.Time `json:"timestamp"`
	// Package is the package of the code when Error is created
	Package string `json:"package"` // lantern
	// Func is the function name when Error is created
	Func string `json:"func"` // foo.Bar
	// FileLine is the file path relative to GOPATH together with the line when
	// Error is created.
	FileLine string `json:"file_line"` // github.com/lantern/foo.go:10
	// Go type name or constant/variable name of the error
	GoType string `json:"type"`
	// Error description, by either Go library or application

	Desc string `json:"desc"`
	// The operation which triggers the error to happen
	Op string `json:"operation,omitempty"`
	// Any extra fields
	Extra map[string]string `json:"extra,omitempty"`

	// ReportFileLine is the file and line where the error is reported
	ReportFileLine string `json:"report_file_line"`
	// ReportTS is the timestamp when Error is reported
	ReportTS time.Time `json:"report_timestamp"`
	// ReportStack is caller's stack when Error is reported
	ReportStack stack.CallStack `json:"-"`

	*ProxyingInfo
	*UserLocale
	*HTTPRequest
	*HTTPResponse
	*SystemInfo
}

// Report calls the reporter supplied during Initialize. It will also call
// golog.Error if errors package is initialized with enableLogging=true.
func (e *Error) Report() {
	curDirector.report(e)
}

// WithOp attaches a hint of the operation triggers this Error. Many error
// types returned by net and os package have Op pre-filled.
func (e *Error) WithOp(op string) *Error {
	e.Op = op
	return e
}

// Request attaches key information of an `http.Request` to the Error.
func (e *Error) Request(r *http.Request) *Error {
	if e.HTTPRequest == nil {
		e.HTTPRequest = &HTTPRequest{}
	}
	e.HTTPRequest.Method = r.Method
	e.HTTPRequest.Scheme = r.URL.Scheme
	e.HTTPRequest.HostInURL = r.URL.Host
	e.HTTPRequest.Host = r.Host
	e.HTTPRequest.Protocol = r.Proto
	e.HTTPRequest.Connection = strings.Join(r.Header["Connection"], ",")
	e.HTTPRequest.Accept = strings.Join(r.Header["Accept"], ",")
	e.HTTPRequest.AcceptLanguage = strings.Join(r.Header["Accept-Language"], ",")
	e.HTTPRequest.UserAgent = r.Header.Get("User-Agent")
	return e
}

// Response attaches key information of an `http.Response` to the Error. If
// the response has corresponding Request, and there's no HTTPRequest in the
// Error, it will call Request internally.
func (e *Error) Response(r *http.Response) *Error {
	if e.HTTPResponse == nil {
		e.HTTPResponse = &HTTPResponse{}
	}
	e.HTTPResponse.StatusCode = r.StatusCode
	e.HTTPResponse.Protocol = r.Proto
	e.HTTPResponse.ContentType = r.Header.Get("Content-Type")
	if r.Request != nil && e.HTTPRequest == nil {
		return e.Request(r.Request)
	}
	return e
}

// ProxyType attaches proxy type to an Error
func (e *Error) ProxyType(v ProxyType) *Error {
	if e.ProxyingInfo == nil {
		e.ProxyingInfo = &ProxyingInfo{}
	}
	e.ProxyingInfo.ProxyType = v
	return e
}

// ProxyAddr attaches proxy server address to an Error
func (e *Error) ProxyAddr(v string) *Error {
	if e.ProxyingInfo == nil {
		e.ProxyingInfo = &ProxyingInfo{}
	}
	e.ProxyingInfo.ProxyAddr = v
	return e
}

// ProxyDatacenter attaches proxy server's datacenter to an Error
func (e *Error) ProxyDatacenter(v string) *Error {
	if e.ProxyingInfo == nil {
		e.ProxyingInfo = &ProxyingInfo{}
	}
	e.ProxyingInfo.Datacenter = v
	return e
}

// OriginSite attaches the site to visit to an Error
func (e *Error) OriginSite(v string) *Error {
	if e.ProxyingInfo == nil {
		e.ProxyingInfo = &ProxyingInfo{}
	}
	e.ProxyingInfo.OriginSite = v
	return e
}

// WithLocale detects and attaches the user locale information to an Error
func (e *Error) WithLocale() *Error {
	lang, _ := localeDetector.DetectLanguage()
	country, _ := localeDetector.DetectTerritory()
	e.UserLocale = &UserLocale{
		time.Now().Format("MST"),
		lang,
		country,
	}
	return e
}

// With attaches arbitrary field to the error. keys will be normalized as
// underscore_divided_words, so all characters except letters and numbers will
// be replaced with underscores, and all letters will be lowercased.
func (e *Error) With(key string, value interface{}) *Error {
	if e.Extra == nil {
		e.Extra = make(map[string]string)
	}
	parts := strings.FieldsFunc(key, func(c rune) bool {
		return !unicode.IsLetter(c) && !unicode.IsNumber(c)
	})
	k := strings.ToLower(strings.Join(parts, "_"))
	switch actual := value.(type) {
	case string:
		e.Extra[k] = actual
	case int:
		e.Extra[k] = strconv.Itoa(actual)
	case bool:
		e.Extra[k] = strconv.FormatBool(actual)
	default:
		e.Extra[k] = fmt.Sprint(value)
	}
	return e
}

// Error satisfies the error interface
func (e *Error) Error() string {
	var buf bytes.Buffer
	e.writeTo(&buf)
	return buf.String()
}

func (e *Error) writeTo(w io.Writer) {
	_, _ = io.WriteString(w, e.Desc)
	if e.Op != "" {
		_, _ = io.WriteString(w, " Op="+e.Op)
	}
	if e.ProxyingInfo != nil {
		_, _ = io.WriteString(w, e.ProxyingInfo.String())
	}
	if e.UserLocale != nil {
		_, _ = io.WriteString(w, e.UserLocale.String())
	}
	if e.HTTPRequest != nil {
		_, _ = io.WriteString(w, e.HTTPRequest.String())
	}
	if e.HTTPResponse != nil {
		_, _ = io.WriteString(w, e.HTTPResponse.String())
	}
	for k, v := range e.Extra {
		_, _ = io.WriteString(w, " "+k+"="+v)
	}
	if e.Func != "" {
		_, _ = io.WriteString(w, " Func="+e.Func)
	}
	if e.GoType != "" {
		_, _ = io.WriteString(w, " GoType="+e.GoType)
	}
	if e.Package != "" {
		_, _ = io.WriteString(w, " Package="+e.Package)
	}
}

func (e *Error) attachStack(skip int) {
	caller := stack.Caller(skip)
	e.Package = fmt.Sprintf("%+k", caller)
	e.Func = fmt.Sprintf("%n", caller)
	e.FileLine = fmt.Sprintf("%+v", caller)
	e.Stack = stack.Trace().TrimBelow(caller).TrimRuntime()
}

func (e *Error) applyDefaults() {
	if e.Source == nil {
		return
	}
	op, goType, desc, extra := parseError(e.Source)
	if e.Op == "" {
		e.Op = op
	}
	if e.GoType == "" {
		e.GoType = goType
	}
	if e.Desc == "" {
		e.Desc = desc
	}
	if e.Extra == nil {
		e.Extra = extra
	} else {
		for key, value := range extra {
			_, found := e.Extra[key]
			if !found {
				e.Extra[key] = value
			}
		}
	}
}

// SystemInfo wraps system information unchangeable during the program
// execution.
type SystemInfo struct {
	OSType     string `json:"os_type"`
	OSVersion  string `json:"os_version"`
	OSArch     string `json:"os_arch"`
	GoVersion  string `json:"go_version"`
	AppVersion string `json:"app_version"`
}

// String returns the string representation of SystemInfo
func (si *SystemInfo) String() string {
	var buf bytes.Buffer
	if si.OSType != "" {
		_, _ = buf.WriteString(" OSType=" + si.OSType)
	}
	if si.OSVersion != "" {
		_, _ = buf.WriteString(" OSVersion=\"" + si.OSVersion + "\"")
	}
	if si.OSArch != "" {
		_, _ = buf.WriteString(" OSArch=" + si.OSArch)
	}
	if si.GoVersion != "" {
		_, _ = buf.WriteString(" GoVersion=\"" + si.GoVersion + "\"")
	}
	if si.AppVersion != "" {
		_, _ = buf.WriteString(" AppVersion=\"" + si.AppVersion + "\"")
	}
	return buf.String()
}

// UserLocale contains locale information gained from operation system.
type UserLocale struct {
	TimeZone string `json:"time_zone,omitempty"`
	Language string `json:"language,omitempty"`
	Country  string `json:"country,omitempty"`
}

// String returns the string representation of UserLocale
func (si *UserLocale) String() string {
	var buf bytes.Buffer
	if si.TimeZone != "" {
		_, _ = buf.WriteString(" TimeZone=" + si.TimeZone)
	}
	if si.Language != "" {
		_, _ = buf.WriteString(" Language=" + si.Language)
	}
	if si.Country != "" {
		_, _ = buf.WriteString(" Country=" + si.Country)
	}
	return buf.String()
}

// ProxyType is the type of various proxy channel
type ProxyType string

const (
	// NoProxy means direct access, not proxying at all
	NoProxy ProxyType = "no_proxy"
	// ChainedProxy means access through Lantern hosted chained server
	ChainedProxy ProxyType = "chained"
	// FrontedProxy means access through domain fronting
	FrontedProxy ProxyType = "fronted"
	// DDF means access through direct domain fronting
	DDF ProxyType = "DDF"
)

// ProxyingInfo encapsulates fields to describe an access through a proxy
// channel.
type ProxyingInfo struct {
	// ProxyType is the type of proxy channel traffic is going through
	ProxyType ProxyType `json:"proxy_type,omitempty"`
	// ProxyAddr is the server traffic is proxied, if any
	ProxyAddr string `json:"proxy_addr,omitempty"`
	// Datacenter is the datacenter where the proxy server resides
	Datacenter string `json:"proxy_datacenter,omitempty"`
	// OriginSite is the site to visit, possibly with port
	OriginSite string `json:"origin_site,omitempty"`
}

// String returns the string representation of ProxyingInfo
func (pi *ProxyingInfo) String() string {
	var buf bytes.Buffer
	if pi.ProxyType != "" {
		_, _ = buf.WriteString(" ProxyType=" + string(pi.ProxyType))
	}
	if pi.ProxyAddr != "" {
		_, _ = buf.WriteString(" ProxyAddr=" + pi.ProxyAddr)
	}
	if pi.Datacenter != "" {
		_, _ = buf.WriteString(" Datacenter=" + pi.Datacenter)
	}
	if pi.OriginSite != "" {
		_, _ = buf.WriteString(" OriginSite=" + pi.OriginSite)
	}
	return buf.String()
}

// HTTPRequest encapsulates key fields of an http.Request
type HTTPRequest struct {
	// Method
	Method string `json:"method,omitempty"`
	// Scheme
	Scheme string `json:"scheme,omitempty"`
	// HostInURL
	HostInURL string `json:"host_in_url,omitempty"`
	// Host
	Host string `json:"host,omitempty"`
	// Protocol
	Protocol string `json:"protocol,omitempty"`
	// Connection header
	Connection string `json:"connection,omitempty"`
	// Accept header
	Accept string `json:"accept,omitempty"`
	// Accept-Language header
	AcceptLanguage string `json:"accept_language,omitempty"`
	// User-Agent header
	UserAgent string `json:"user_agent,omitempty"`
}

func (r *HTTPRequest) String() string {
	var buf bytes.Buffer
	_, _ = buf.WriteString(fmt.Sprintf(" Request=\"%s %s://%s %s\"", r.Method, r.Scheme, r.HostInURL, r.Protocol))
	if r.Host != "" {
		_, _ = buf.WriteString(fmt.Sprintf(" Host=%s", r.Host))
	}
	if r.Connection != "" {
		_, _ = buf.WriteString(fmt.Sprintf(" Connection=\"%s\"", r.Connection))
	}
	if r.Accept != "" {
		_, _ = buf.WriteString(fmt.Sprintf(" Accept=\"%s\"", r.Accept))
	}
	if r.AcceptLanguage != "" {
		_, _ = buf.WriteString(fmt.Sprintf(" Accept-Language=\"%s\"", r.AcceptLanguage))
	}
	if r.UserAgent != "" {
		_, _ = buf.WriteString(fmt.Sprintf(" User-Agent=\"%s\"", r.UserAgent))
	}
	return buf.String()
}

// HTTPResponse encapsulates key fields of an http.Response
type HTTPResponse struct {
	// StatusCode
	StatusCode int `json:"status_code,omitempty"`
	// Protocol
	Protocol string `json:"protocol,omitempty"`
	// ContentType
	ContentType string `json:"content_type,omitempty"`
}

func (r *HTTPResponse) String() string {
	return fmt.Sprintf(" Response=\"%s %d\" Content-Type=\"%s\"", r.Protocol, r.StatusCode, r.ContentType)
}

func parseError(err error) (op string, goType string, desc string, extra map[string]string) {
	extra = make(map[string]string)

	// interfaces
	if _, ok := err.(net.Error); ok {
		if opError, ok := err.(*net.OpError); ok {
			op = opError.Op
			if opError.Source != nil {
				extra["local_addr"] = opError.Source.String()
			}
			if opError.Addr != nil {
				extra["remote_addr"] = opError.Addr.String()
			}
			extra["network"] = opError.Net
			err = opError.Err
		}
		switch actual := err.(type) {
		case *net.AddrError:
			goType = "net.AddrError"
			desc = actual.Err
			extra["addr"] = actual.Addr
		case *net.DNSError:
			goType = "net.DNSError"
			desc = actual.Err
			extra["domain"] = actual.Name
			if actual.Server != "" {
				extra["dns_server"] = actual.Server
			}
		case *net.InvalidAddrError:
			goType = "net.InvalidAddrError"
			desc = actual.Error()
		case *net.ParseError:
			goType = "net.ParseError"
			desc = "invalid " + actual.Type
			extra["text_to_parse"] = actual.Text
		case net.UnknownNetworkError:
			goType = "net.UnknownNetworkError"
			desc = "unknown network"
		case syscall.Errno:
			goType = "syscall.Errno"
			desc = actual.Error()
		case *url.Error:
			goType = "url.Error"
			desc = actual.Err.Error()
			op = actual.Op
		default:
			goType = reflect.TypeOf(err).String()
			desc = err.Error()
		}
		return
	}
	if _, ok := err.(runtime.Error); ok {
		desc = err.Error()
		switch err.(type) {
		case *runtime.TypeAssertionError:
			goType = "runtime.TypeAssertionError"
		default:
			goType = reflect.TypeOf(err).String()
		}
		return
	}

	// structs
	switch actual := err.(type) {
	case *http.ProtocolError:
		desc = actual.ErrorString
		if name, ok := httpProtocolErrors[err]; ok {
			goType = name
		} else {
			goType = "http.ProtocolError"
		}
	case url.EscapeError, *url.EscapeError:
		goType = "url.EscapeError"
		desc = "invalid URL escape"
	case url.InvalidHostError, *url.InvalidHostError:
		goType = "url.InvalidHostError"
		desc = "invalid character in host name"
	case *textproto.Error:
		goType = "textproto.Error"
		desc = actual.Error()
	case textproto.ProtocolError, *textproto.ProtocolError:
		goType = "textproto.ProtocolError"
		desc = actual.Error()

	case tls.RecordHeaderError:
		goType = "tls.RecordHeaderError"
		desc = actual.Msg
		extra["header"] = hex.EncodeToString(actual.RecordHeader[:])
	case x509.CertificateInvalidError:
		goType = "x509.CertificateInvalidError"
		desc = actual.Error()
	case x509.ConstraintViolationError:
		goType = "x509.ConstraintViolationError"
		desc = actual.Error()
	case x509.HostnameError:
		goType = "x509.HostnameError"
		desc = actual.Error()
		extra["host"] = actual.Host
	case x509.InsecureAlgorithmError:
		goType = "x509.InsecureAlgorithmError"
		desc = actual.Error()
	case x509.SystemRootsError:
		goType = "x509.SystemRootsError"
		desc = actual.Error()
	case x509.UnhandledCriticalExtension:
		goType = "x509.UnhandledCriticalExtension"
		desc = actual.Error()
	case x509.UnknownAuthorityError:
		goType = "x509.UnknownAuthorityError"
		desc = actual.Error()
	case hex.InvalidByteError:
		goType = "hex.InvalidByteError"
		desc = "invalid byte"
	case *json.InvalidUTF8Error:
		goType = "json.InvalidUTF8Error"
		desc = "invalid UTF-8 in string"
	case *json.InvalidUnmarshalError:
		goType = "json.InvalidUnmarshalError"
		desc = actual.Error()
	case *json.MarshalerError:
		goType = "json.MarshalerError"
		desc = actual.Error()
	case *json.SyntaxError:
		goType = "json.SyntaxError"
		desc = actual.Error()
	case *json.UnmarshalFieldError:
		goType = "json.UnmarshalFieldError"
		desc = actual.Error()
	case *json.UnmarshalTypeError:
		goType = "json.UnmarshalTypeError"
		desc = actual.Error()
	case *json.UnsupportedTypeError:
		goType = "json.UnsupportedTypeError"
		desc = actual.Error()
	case *json.UnsupportedValueError:
		goType = "json.UnsupportedValueError"
		desc = actual.Error()

	case *os.LinkError:
		goType = "os.LinkError"
		desc = actual.Error()
	case *os.PathError:
		goType = "os.PathError"
		op = actual.Op
		desc = actual.Err.Error()
	case *os.SyscallError:
		goType = "os.SyscallError"
		op = actual.Syscall
		desc = actual.Err.Error()
	case *exec.Error:
		goType = "exec.Error"
		desc = actual.Err.Error()
	case *exec.ExitError:
		goType = "exec.ExitError"
		desc = actual.Error()
		// TODO: limit the length
		extra["stderr"] = string(actual.Stderr)
	case *strconv.NumError:
		goType = "strconv.NumError"
		desc = actual.Err.Error()
		extra["function"] = actual.Func
	case *time.ParseError:
		goType = "time.ParseError"
		desc = actual.Message
	default:
		desc = err.Error()
		if t, ok := miscErrors[err]; ok {
			goType = t
			return
		}
		goType = reflect.TypeOf(err).String()
	}
	return
}

var httpProtocolErrors = map[error]string{
	http.ErrHeaderTooLong:        "http.ErrHeaderTooLong",
	http.ErrShortBody:            "http.ErrShortBody",
	http.ErrNotSupported:         "http.ErrNotSupported",
	http.ErrUnexpectedTrailer:    "http.ErrUnexpectedTrailer",
	http.ErrMissingContentLength: "http.ErrMissingContentLength",
	http.ErrNotMultipart:         "http.ErrNotMultipart",
	http.ErrMissingBoundary:      "http.ErrMissingBoundary",
}

var miscErrors = map[error]string{
	bufio.ErrInvalidUnreadByte: "bufio.ErrInvalidUnreadByte",
	bufio.ErrInvalidUnreadRune: "bufio.ErrInvalidUnreadRune",
	bufio.ErrBufferFull:        "bufio.ErrBufferFull",
	bufio.ErrNegativeCount:     "bufio.ErrNegativeCount",
	bufio.ErrTooLong:           "bufio.ErrTooLong",
	bufio.ErrNegativeAdvance:   "bufio.ErrNegativeAdvance",
	bufio.ErrAdvanceTooFar:     "bufio.ErrAdvanceTooFar",
	bufio.ErrFinalToken:        "bufio.ErrFinalToken",

	http.ErrWriteAfterFlush:    "http.ErrWriteAfterFlush",
	http.ErrBodyNotAllowed:     "http.ErrBodyNotAllowed",
	http.ErrHijacked:           "http.ErrHijacked",
	http.ErrContentLength:      "http.ErrContentLength",
	http.ErrBodyReadAfterClose: "http.ErrBodyReadAfterClose",
	http.ErrHandlerTimeout:     "http.ErrHandlerTimeout",
	http.ErrLineTooLong:        "http.ErrLineTooLong",
	http.ErrMissingFile:        "http.ErrMissingFile",
	http.ErrNoCookie:           "http.ErrNoCookie",
	http.ErrNoLocation:         "http.ErrNoLocation",
	http.ErrSkipAltProtocol:    "http.ErrSkipAltProtocol",

	io.EOF:              "io.EOF",
	io.ErrClosedPipe:    "io.ErrClosedPipe",
	io.ErrNoProgress:    "io.ErrNoProgress",
	io.ErrShortBuffer:   "io.ErrShortBuffer",
	io.ErrShortWrite:    "io.ErrShortWrite",
	io.ErrUnexpectedEOF: "io.ErrUnexpectedEOF",

	os.ErrInvalid:    "os.ErrInvalid",
	os.ErrPermission: "os.ErrPermission",
	os.ErrExist:      "os.ErrExist",
	os.ErrNotExist:   "os.ErrNotExist",

	exec.ErrNotFound: "exec.ErrNotFound",

	x509.ErrUnsupportedAlgorithm: "x509.ErrUnsupportedAlgorithm",
	x509.IncorrectPasswordError:  "x509.IncorrectPasswordError",

	hex.ErrLength: "hex.ErrLength",
}
