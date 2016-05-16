// Package context wraps github.com/getlantern/context with convenience methods
// for flashlight
package context

import (
	"net"
	"net/http"
	"strings"

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
	// ProxyDDF means access through direct domain fronting
	ProxyDDF ProxyType = "DDF"
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

// AsMap mimics the similar method from context.Context
func (c *Context) AsMap() map[string]interface{} {
	return c.ctx.AsMap()
}

// AsMap mimics the similar method from context
func AsMap() map[string]interface{} {
	return context.AsMap()
}

// AsMapWithoutGlobals mimics the similar method from context
func AsMapWithoutGlobals() map[string]interface{} {
	return context.AsMapWithoutGlobals()
}

// AsMapWith mimics the similar method from context
func AsMapWith(cl context.Contextual) map[string]interface{} {
	return context.AsMapWithoutGlobals()
}

// OuterOp attaches an operation to the Context.
func (c *Context) OuterOp(v string) *Context {
	c.ctx.Put("op", v)
	return c
}

// BackgroundOp attaches an inner (bottom level) operation to the Context.
func (c *Context) BackgroundOp(v string) *Context {
	c.ctx.Put("background_op", v)
	return c
}

// UserAgent attaches a user agent to the Context.
func (c *Context) UserAgent(v string) *Context {
	c.ctx.Put("user_agent", v)
	return c
}

// RequestID attaches a request id to the Context.
func (c *Context) RequestID(v int64) *Context {
	c.ctx.Put("request_id", v)
	return c
}

// Request attaches key information of an `http.Request` to the Context.
func (c *Context) Request(r *http.Request) *Context {
	if r == nil {
		return c
	}
	c.ctx.Put("http_request_method", r.Method).
		Put("http_request_scheme", r.URL.Scheme).
		Put("http_request_host_in_url", r.URL.Host).
		Put("http_request_host", r.Host).
		Put("http_request_protocol", r.Proto).
		Put("http_request_header_connection", strings.Join(r.Header["Connection"], ",")).
		Put("http_request_header_accept", strings.Join(r.Header["Accept"], ",")).
		Put("http_request_header_accept_language", strings.Join(r.Header["Accept-Language"], ",")).
		Put("http_request_user_agent", r.Header.Get("User-Agent"))
	return c
}

// Response attaches key information of an `http.Response` to the Context. If
// the response has corresponding Request it will call Request internally.
func (c *Context) Response(r *http.Response) *Context {
	if r == nil {
		return c
	}
	c.ctx.Put("http_response_status_code", r.StatusCode).
		Put("http_response_protocol", r.Proto).
		Put("http_response_content_type", r.Header.Get("Content-Type"))
	c.Request(r.Request)
	return c
}

// ChainedProxy attaches chained proxy information to the Context
func (c *Context) ChainedProxy(addr string, protocol string) *Context {
	c.ProxyType(ProxyChained)
	c.ProxyAddr(addr)
	return c.ProxyProtocol(protocol)
}

// ProxyType attaches proxy type to the Context
func (c *Context) ProxyType(v ProxyType) *Context {
	c.ctx.Put("proxy_type", v)
	return c
}

// ProxyAddr attaches proxy server address to the Contetx
func (c *Context) ProxyAddr(v string) *Context {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		c.ctx.Put("proxy_host", host).Put("proxy_port", port)
	}
	return c
}

// ProxyProtocol attaches proxy server's protocol to the Contetx
func (c *Context) ProxyProtocol(v string) *Context {
	c.ctx.Put("proxy_protocol", v)
	return c
}

// ProxyDatacenter attaches proxy server's datacenter to the Contetx
func (c *Context) ProxyDatacenter(v string) *Context {
	c.ctx.Put("proxy_datacenter", v)
	return c
}

// Origin attaches the origin to the Contetx
func (c *Context) Origin(v string) *Context {
	host, port, err := net.SplitHostPort(v)
	if err == nil {
		c.ctx.Put("origin_host", host).Put("origin_port", port)
	}
	return c
}
