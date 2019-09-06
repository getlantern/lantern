// Package ops wraps github.com/getlantern/ops with convenience methods
// for flashlight
package ops

import (
	"net"
	"net/http"

	"github.com/getlantern/ops"
)

// ProxyType is the type of various proxy channel
type ProxyType string

const (
	// ProxyNone means direct access, not proxying at all
	ProxyNone ProxyType = "none"
	// ProxyChained means access through Lantern hosted chained server
	ProxyChained ProxyType = "chained"
	// ProxyFronted means access through domain fronting
	ProxyFronted ProxyType = "fronted"
)

// Op decorates an ops.Op with convenience methods.
type Op struct {
	wrapped ops.Op
}

// Begin mimics the similar method from ops.Op
func (op *Op) Begin(name string) *Op {
	return &Op{op.wrapped.Begin(name)}
}

// Begin mimics the similar method from ops
func Begin(name string) *Op {
	return &Op{ops.Begin(name)}
}

// RegisterReporter mimics the similar method from ops
func RegisterReporter(reporter ops.Reporter) {
	ops.RegisterReporter(reporter)
}

// Go mimics the similar method from ops.Op
func (op *Op) Go(fn func()) {
	op.wrapped.Go(fn)
}

// Go mimics the similar method from ops.
func Go(fn func()) {
	ops.Go(fn)
}

// End mimics the similar method from ops.Op
func (op *Op) End() {
	op.wrapped.End()
}

// Set mimics the similar method from ops.Op
func (op *Op) Set(key string, value interface{}) *Op {
	op.wrapped.Set(key, value)
	return op
}

// SetGlobal mimics the similar method from ops
func SetGlobal(key string, value interface{}) {
	ops.SetGlobal(key, value)
}

// SetDynamic mimics the similar method from ops.Op
func (op *Op) SetDynamic(key string, valueFN func() interface{}) *Op {
	op.wrapped.SetDynamic(key, valueFN)
	return op
}

// SetGlobalDynamic mimics the similar method from ops
func SetGlobalDynamic(key string, valueFN func() interface{}) {
	ops.SetGlobalDynamic(key, valueFN)
}

// FailIf mimics the similar method from ops.op
func (op *Op) FailIf(err error) error {
	return op.wrapped.FailIf(err)
}

// UserAgent attaches a user agent to the Context.
func (op *Op) UserAgent(v string) *Op {
	op.Set("user_agent", v)
	return op
}

// Request attaches key information of an `http.Request` to the Context.
func (op *Op) Request(r *http.Request) *Op {
	if r == nil {
		return op
	}
	op.Set("http_method", r.Method).
		Set("http_proto", r.Proto).
		Set("origin", r.Host)
	host, port, err := net.SplitHostPort(r.Host)
	if err == nil {
		op.Set("origin_host", host).Set("origin_port", port)
	}
	return op
}

// Response attaches key information of an `http.Response` to the Context. If
// the response has corresponding Request it will call Request internally.
func (op *Op) Response(r *http.Response) *Op {
	if r == nil {
		return op
	}
	op.Set("http_response_status_code", r.StatusCode)
	op.Request(r.Request)
	return op
}

// ChainedProxy attaches chained proxy information to the Context
func (op *Op) ChainedProxy(addr string, protocol string) *Op {
	return op.ProxyType(ProxyChained).
		ProxyAddr(addr).
		ProxyProtocol(protocol)
}

// ProxyType attaches proxy type to the Context
func (op *Op) ProxyType(v ProxyType) *Op {
	return op.Set("proxy_type", v)
}

// ProxyAddr attaches proxy server address to the Context
func (op *Op) ProxyAddr(v string) *Op {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		op.Set("proxy_host", host).Set("proxy_port", port)
	}
	return op
}

// ProxyProtocol attaches proxy server's protocol to the Context
func (op *Op) ProxyProtocol(v string) *Op {
	return op.Set("proxy_protocol", v)
}

// Origin attaches the origin to the Contetx
func (op *Op) Origin(v string) *Op {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		op.Set("origin_host", host).Set("origin_port", port)
	}
	return op
}
