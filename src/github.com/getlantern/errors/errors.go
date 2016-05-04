/*
Package errors defines error interfaces and types used across Lantern project
and implements functions to manipulate them.
*/

package errors

import (
	"bufio"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/textproto"
	"net/url"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"syscall"
	"time"
)

type Error struct {
	error
	module string
}

type ProxyError struct {
	Error
	via   via
	layer layer
}

type SystemError struct {
	Error
}

type BrowserError struct {
	Error
}

func New(err error) Error {
	// interface
	if _, ok := err.(net.Error); ok {
		switch err.(type) {
		case *net.AddrError:
		// case *net.DNSConfigError: no longer used by Go, leave here to make sure we don't miss anything
		case *net.DNSError:
		case *net.InvalidAddrError:
		case *net.OpError:
		case *net.ParseError:
		case net.UnknownNetworkError:
		case syscall.Errno:
		default:
		}
		return Error{}
	}
	// struct
	switch err.(type) {
	case *http.ProtocolError:
		if name := httpProtocolErrors[err]; name != "" {
		}
	case *url.Error:
	case url.EscapeError, *url.EscapeError:
	case url.InvalidHostError, *url.InvalidHostError:
	case *textproto.Error:
	case textproto.ProtocolError, *textproto.ProtocolError:
	case *os.LinkError:
	case *os.PathError:
	case *os.SyscallError:
	case *exec.Error:
	case *exec.ExitError:
	case runtime.Error:
	case *runtime.TypeAssertionError:
	case tls.RecordHeaderError:
	case x509.CertificateInvalidError:
	case x509.ConstraintViolationError:
	case x509.HostnameError:
	case x509.InsecureAlgorithmError:
	case x509.SystemRootsError:
	case x509.UnhandledCriticalExtension:
	case x509.UnknownAuthorityError:
	case hex.InvalidByteError:
	case *json.InvalidUTF8Error:
	case *json.InvalidUnmarshalError:
	case *json.MarshalerError:
	case *json.SyntaxError:
	case *json.UnmarshalFieldError:
	case *json.UnmarshalTypeError:
	case *json.UnsupportedTypeError:
	case *json.UnsupportedValueError:
	case *strconv.NumError:
	case *time.ParseError:
	default:
		if name := httpProtocolErrors[err]; name != "" {
		}
		// errors.New
	}
	return Error{}
}

type layer int

const (
	PayloadLayer = iota
	HTTPLayer
	NetLayer
)

var layerDescription = [...]string{
	"PayloadLayer",
	"HTTPLayer",
	"TCPLayer",
}

func (l layer) String() string {
	return layerDescription[l]
}

type via int

const (
	viaDirect = iota
	viaChained
	viaFronted
)

var viaDescription = [...]string{
	"viaDirect",
	"viaChained",
	"viaFronted",
}

func (v via) String() string {
	return viaDescription[v]
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

	io.EOF:              "http.EOF",
	io.ErrClosedPipe:    "http.ErrClosedPipe",
	io.ErrNoProgress:    "http.ErrNoProgress",
	io.ErrShortBuffer:   "http.ErrShortBuffer",
	io.ErrShortWrite:    "http.ErrShortWrite",
	io.ErrUnexpectedEOF: "http.ErrUnexpectedEOF",

	os.ErrInvalid:    "os.ErrInvalid",
	os.ErrPermission: "os.ErrPermission",
	os.ErrExist:      "os.ErrExist",
	os.ErrNotExist:   "os.ErrNotExist",

	exec.ErrNotFound: "exec.ErrNotFound",

	x509.ErrUnsupportedAlgorithm: "x509.ErrUnsupportedAlgorithm",
	x509.IncorrectPasswordError:  "x509.IncorrectPasswordError",

	hex.ErrLength: "hex.ErrLength",
}
