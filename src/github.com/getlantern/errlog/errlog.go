/*
Package errlog defines error types used across Lantern project and implements
functions to manipulate them.

  var elog = errlog.ErrorLoggerFor("package-name")
  //...
  if n, err := Foo(); err != nil {
    elog.Log(err)
  }

Log() method will try as much as possible to extract details from the error
passed in, if it's errors defined in Go standard library. For application
defined error type, at least the Go type name and what yourErr.Error() returns
will be recorded.

Extra parameters can be passed like this in any order.
  elog.Log(err, errlog.WithOp("proxy"), errlog.WithUserAgent("Mozilla/5.0..."))

Or to attach arbitrary data with the error.
  elog.Log(err, errlog.WithField("foo": "bar"))

Guildlines to report error:

1. Report at the end of error propagation chain, that is, before the code
resumes from the error or makes a decision based on it.

2. Report when more relevant knowledge is available.

The purpose is to avoid reporting repetitively, and prevent lower level of code
from depending on this package.
*/
package errlog

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
	"syscall"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/jibber_jabber"
	"github.com/getlantern/osversion"
)

type systemInfo struct {
	OSType    string `json:"osType"`
	OSVersion string `json:"osVersion"`
	OSArch    string `json:"osArch"`
}

var (
	defaultSystemInfo *systemInfo
	userLocale        *UserLocale
)

func init() {
	version, _ := osversion.GetHumanReadable()

	defaultSystemInfo = &systemInfo{
		OSType:    runtime.GOOS,
		OSArch:    runtime.GOARCH,
		OSVersion: version,
	}

	lang, _ := jibber_jabber.DetectLanguage()
	country, _ := jibber_jabber.DetectTerritory()
	userLocale = &UserLocale{
		time.Now().Format("MST"),
		lang,
		country,
	}
}

func (si *systemInfo) String() string {
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
	return buf.String()
}

type UserLocale struct {
	TimeZone string `json:"timeZone,omitempty"`
	Language string `json:"language,omitempty"`
	Country  string `json:"country,omitempty"`
}

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
	// direct access, no proxying at all
	NoProxy ProxyType = "no"
	// access through Lantern hosted chained server
	ChainedProxy ProxyType = "chained"
	// access through domain fronting
	FrontedProxy ProxyType = "fronted"
	// access through direct domain fronting
	DirectFrontedProxy ProxyType = "DDF"
)

// ProxyingInfo encapsulates fields to describe an access through a proxy channel.
type ProxyingInfo struct {
	ProxyType  ProxyType `json:"proxyType,omitempty"`
	LocalAddr  string    `json:"localAddr,omitempty"`
	ProxyAddr  string    `json:"proxyAddr,omitempty"`
	ProxyDC    string    `json:"proxyDataCenter,omitempty"`
	OriginSite string    `json:"originSite,omitempty"`
	Scheme     string    `json:"scheme,omitempty"`
}

func (pi *ProxyingInfo) String() string {
	var buf bytes.Buffer
	if pi.ProxyType != "" {
		_, _ = buf.WriteString(" ProxyType=" + string(pi.ProxyType))
	}
	if pi.LocalAddr != "" {
		_, _ = buf.WriteString(" LocalAddr=" + pi.LocalAddr)
	}
	if pi.ProxyAddr != "" {
		_, _ = buf.WriteString(" ProxyAddr=" + pi.ProxyAddr)
	}
	if pi.ProxyDC != "" {
		_, _ = buf.WriteString(" ProxyDC=" + pi.ProxyDC)
	}
	if pi.OriginSite != "" {
		_, _ = buf.WriteString(" OriginSite=" + pi.OriginSite)
	}
	if pi.Scheme != "" {
		_, _ = buf.WriteString(" Scheme=" + pi.Scheme)
	}
	return buf.String()
}

// UserAgentInfo encapsulates traits of the browsers or 3rd party applications
// directing traffic through Lantern.
type UserAgentInfo struct {
	UserAgent string `json:"userAgent,omitempty"`
}

func (ul *UserAgentInfo) String() string {
	return fmt.Sprintf("UserAgent=%s", ul.UserAgent)
}

// Error wraps system and application errors in unified structure
type Error struct {
	// Source captures the underlying error that's wrapped by this Error
	Source error `json:"-"`
	// Go package reports the error
	GoPackage string `json:"package"`
	// Go type name or constant/variable name of the error
	GoType string `json:"type"`
	// Error description, by either Go library or application
	Desc string `json:"desc"`
	// The operation which triggers the error to happen
	Op string `json:"operation,omitempty"`
	// Any extra fields
	Extra map[string]string `json:"extra,omitempty"`

	*ProxyingInfo
	*UserLocale
	*UserAgentInfo
}

func (e *Error) Error() string {
	return e.String()
}

func (e *Error) String() string {
	var buf bytes.Buffer
	_, _ = buf.WriteString(e.Desc)
	if e.Op != "" {
		_, _ = buf.WriteString(" op=" + e.Op)
	}
	if e.ProxyingInfo != nil {
		_, _ = buf.WriteString(e.ProxyingInfo.String())
	}
	if e.UserLocale != nil {
		_, _ = buf.WriteString(e.UserLocale.String())
	}
	if e.UserAgentInfo != nil {
		_, _ = buf.WriteString(e.UserAgentInfo.String())
	}
	for k, v := range e.Extra {
		_, _ = buf.WriteString(" " + k + "=" + v)
	}
	return buf.String()
}

// Customized marshaller to marshal extra fields to same level as other struct fields
/*func (e Error) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	// safe to ignore return value as error returned is always nil
	_, _ = buf.WriteString(fmt.Sprintf(`{"package":"%s","type":"%s","desc":"%s"`, e.GoPackage, e.GoType, e.Desc))
	if e.Extra != nil && len(e.Extra) > 0 {
		_, _ = buf.WriteString(",")
		for k, v := range e.Extra {
			_, _ = buf.WriteString(fmt.Sprintf(`"%s":"%s"`, k, v))
		}
	}
	_, _ = buf.WriteString("}")
	return buf.Bytes(), nil
}*/

type ErrorLogger struct {
	goPackage string
	logger    golog.Logger
}

func (c *ErrorLogger) Log(source error) {
	err, ok := source.(*Error)
	if !ok {
		// Supplied error was not an Error, wrap it
		err = &Error{Source: source}
	}
	c.applyDefaults(err)
	currentReporter.Report(err)
	c.logger.Error(err.String())
}

func (c *ErrorLogger) applyDefaults(err *Error) {
	if err.GoPackage == "" {
		// Default GoPackage
		err.GoPackage = c.goPackage
	}

	if err.Source != nil {
		errOp, goType, desc, extra := parseError(err.Source)
		if err.Op == "" {
			err.Op = errOp
		}
		if err.GoType == "" {
			err.GoType = goType
		}
		if err.Desc == "" {
			err.Desc = desc
		}
		if err.UserLocale == nil {
			err.UserLocale = userLocale
		}
		if err.Extra == nil {
			err.Extra = extra
		} else {
			for key, value := range extra {
				_, found := err.Extra[key]
				if !found {
					err.Extra[key] = value
				}
			}
		}
	}
}

func ErrorLoggerFor(goPackage string) *ErrorLogger {
	return &ErrorLogger{
		goPackage: goPackage,
		logger:    golog.LoggerFor(goPackage),
	}
}

type Reporter interface {
	Report(*Error)
}

var currentReporter Reporter = &StdReporter{}

func ReportTo(r Reporter) {
	currentReporter = r
}

func toJSON(e *Error) []byte {
	b, err := json.Marshal(e)
	if err != nil {
		panic(fmt.Sprintf("failed to convert error to json: %+v", err))
	}
	return b
}

type StdReporter struct {
}

func (l StdReporter) Report(e *Error) {
	fmt.Printf("%+v", string(toJSON(e)))
}

func parseError(err error) (op string, goType string, desc string, extra map[string]string) {
	extra = make(map[string]string)

	// interfaces
	if _, ok := err.(net.Error); ok {
		if opError, ok := err.(*net.OpError); ok {
			op = opError.Op
			if opError.Source != nil {
				extra["localAddr"] = opError.Source.String()
			}
			if opError.Addr != nil {
				extra["remoteAddr"] = opError.Addr.String()
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
				extra["dnsServer"] = actual.Server
			}
		case *net.InvalidAddrError:
			goType = "net.InvalidAddrError"
			desc = actual.Error()
		case *net.ParseError:
			goType = "net.ParseError"
			desc = "invalid " + actual.Type
			extra["textToParse"] = actual.Text
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
