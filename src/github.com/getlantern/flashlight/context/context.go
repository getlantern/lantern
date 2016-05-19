// Package context wraps github.com/getlantern/context with convenience methods
// for flashlight
package context

import (
	"net"
	"net/http"

	"github.com/getlantern/context"
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

// Context decorates a context.Context with convenience methods.
type Context struct {
	ctx *context.Context
}

// Enter mimics the similar method from context.Context
func (c *Context) Enter() *Context {
	return &Context{c.ctx.Enter()}
}

// Enter mimics the similar method from Context
func Enter() *Context {
	return &Context{context.Enter()}
}

// Go mimics the similar method from context.Context
func (c *Context) Go(fn func()) {
	c.ctx.Go(fn)
}

// Go mimics the similar method from context.
func Go(fn func()) {
	context.Go(fn)
}

// Exit mimics the similar method from context.Context
func (c *Context) Exit() *Context {
	ctx := c.ctx.Exit()
	if ctx == nil {
		return nil
	}
	return &Context{ctx}
}

// Put mimics the similar method from context.Context
func (c *Context) Put(key string, value interface{}) *Context {
	c.ctx.Put(key, value)
	return c
}

// PutGlobal mimics the similar method from context
func PutGlobal(key string, value interface{}) {
	context.PutGlobal(key, value)
}

// PutDynamic mimics the similar method from context.Context
func (c *Context) PutDynamic(key string, valueFN func() interface{}) *Context {
	c.ctx.PutDynamic(key, valueFN)
	return c
}

// PutGlobalDynamic mimics the similar method from context
func PutGlobalDynamic(key string, valueFN func() interface{}) {
	context.PutGlobalDynamic(key, valueFN)
}

// AsMap mimics the interfaces from context
func AsMap(obj interface{}, includeGlobals bool) map[string]interface{} {
	return context.AsMap(obj, includeGlobals)
}

// Op attaches an operation to the Context.
func (c *Context) Op(v string) *Context {
	c.Put("op", v)
	return c
}

// BackgroundOp attaches an inner (bottom level) operation to the Context.
func (c *Context) BackgroundOp(v string) *Context {
	c.Put("background_op", v)
	return c
}

// UserAgent attaches a user agent to the Context.
func (c *Context) UserAgent(v string) *Context {
	c.Put("user_agent", v)
	return c
}

// Request attaches key information of an `http.Request` to the Context.
func (c *Context) Request(r *http.Request) *Context {
	if r == nil {
		return c
	}
	return c.Put("http_request_method", r.Method).
		Put("http_request_host", r.Host).
		Put("http_request_proto", r.Proto)
}

// Response attaches key information of an `http.Response` to the Context. If
// the response has corresponding Request it will call Request internally.
func (c *Context) Response(r *http.Response) *Context {
	if r == nil {
		return c
	}
	c.Put("http_response_status_code", r.StatusCode)
	c.Request(r.Request)
	return c
}

// ChainedProxy attaches chained proxy information to the Context
func (c *Context) ChainedProxy(addr string, protocol string) *Context {
	return c.ProxyType(ProxyChained).
		ProxyAddr(addr).
		ProxyProtocol(protocol)
}

// ProxyType attaches proxy type to the Context
func (c *Context) ProxyType(v ProxyType) *Context {
	return c.Put("proxy_type", v)
}

// ProxyAddr attaches proxy server address to the Context
func (c *Context) ProxyAddr(v string) *Context {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		c.ctx.Put("proxy_host", host).Put("proxy_port", port)
	}
	return c
}

// ProxyProtocol attaches proxy server's protocol to the Context
func (c *Context) ProxyProtocol(v string) *Context {
	return c.Put("proxy_protocol", v)
}

// Origin attaches the origin to the Contetx
func (c *Context) Origin(v string) *Context {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		c.ctx.Put("origin_host", host).Put("origin_port", port)
	}
	return c
}
