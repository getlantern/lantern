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

// Enter mimics the similar method from ops.Op
func (op *Op) Enter(name string) *Op {
	return &Op{op.wrapped.Enter(name)}
}

// Enter mimics the similar method from ops
func Enter(name string) *Op {
	op := &Op{ops.Enter(name)}
	// Using "application" allows us to distinguish between errors from the
	// lantern client vs other sources like the http-proxy, etop.
	return op.Put("app", "lantern-client")
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

// Exit mimics the similar method from ops.Op
func (op *Op) Exit() {
	op.wrapped.Exit()
}

// Put mimics the similar method from ops.Op
func (op *Op) Put(key string, value interface{}) *Op {
	op.wrapped.Put(key, value)
	return op
}

// PutDynamic mimics the similar method from ops.Op
func (op *Op) PutDynamic(key string, valueFN func() interface{}) *Op {
	op.wrapped.PutDynamic(key, valueFN)
	return op
}

// Error mimics the similar method from ops.op
func (op *Op) Error(err error) error {
	return op.wrapped.Error(err)
}

// UserAgent attaches a user agent to the Context.
func (op *Op) UserAgent(v string) *Op {
	op.Put("user_agent", v)
	return op
}

// Request attaches key information of an `http.Request` to the Context.
func (op *Op) Request(r *http.Request) *Op {
	if r == nil {
		return op
	}
	return op.Put("http_request_method", r.Method).
		Put("http_request_host", r.Host).
		Put("http_request_proto", r.Proto)
}

// Response attaches key information of an `http.Response` to the Context. If
// the response has corresponding Request it will call Request internally.
func (op *Op) Response(r *http.Response) *Op {
	if r == nil {
		return op
	}
	op.Put("http_response_status_code", r.StatusCode)
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
	return op.Put("proxy_type", v)
}

// ProxyAddr attaches proxy server address to the Context
func (op *Op) ProxyAddr(v string) *Op {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		op.wrapped.Put("proxy_host", host).Put("proxy_port", port)
	}
	return op
}

// ProxyProtocol attaches proxy server's protocol to the Context
func (op *Op) ProxyProtocol(v string) *Op {
	return op.Put("proxy_protocol", v)
}

// Origin attaches the origin to the Contetx
func (op *Op) Origin(v string) *Op {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		op.wrapped.Put("origin_host", host).Put("origin_port", port)
	}
	return op
}
