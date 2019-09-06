package filters

import (
	"net/http"

	"github.com/getlantern/errors"

	"github.com/getlantern/http-proxy/utils"
)

// Filter is like an http.Handler that
type Filter interface {
	// Apply is like the function on http.Handler but also gets a Next which
	// allows it to continue execution along the current filter chain. If Apply
	// returns an error, we will write an appropriate status code to the response.
	// Tip - use filters.Fail() to provide an error with a description.
	Apply(w http.ResponseWriter, req *http.Request, next Next) error
}

// Next is an interface for calling the next Filter in the chain.
type Next func() error

// Chain is a chain of Filters that acts as an http.Handler.
type Chain []Filter

// Fail fails execution of the current chain
func Fail(msg string, args ...interface{}) error {
	return errors.New(msg, args...)
}

// Stop stops execution of the current chain
func Stop() error {
	return nil
}

// Join constructs a new chain of filters that executes the filters in order
// until it encounters a filter that returns false.
func Join(filters ...Filter) Chain {
	return Chain(filters)
}

// Append creates a new Chain by appending the given filters.
func (c Chain) Append(post ...Filter) Chain {
	return append(c, post...)
}

// Prepend creates a new chain by prepending the given filter.
func (c Chain) Prepend(pre Filter) Chain {
	result := make(Chain, len(c)+1)
	result[0] = pre
	copy(result[1:], c)
	return result
}

func (c Chain) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if len(c) == 0 {
		return
	}
	n := &next{w, req, c[1:]}
	err := c[0].Apply(w, req, n.Do)
	if err != nil {
		utils.DefaultHandler.ServeHTTP(w, req, err)
	}
}

type next struct {
	w         http.ResponseWriter
	req       *http.Request
	remaining []Filter
}

func (n *next) Do() error {
	if len(n.remaining) == 0 {
		return nil
	}

	current := n.remaining[0]
	nextN := &next{n.w, n.req, n.remaining[1:]}
	return errors.Wrap(current.Apply(n.w, n.req, nextN.Do))
}

// Adapt adapts an existing http.Handler to the Filter interface.
func Adapt(handler http.Handler) Filter {
	return &wrapper{handler}
}

type wrapper struct {
	handler http.Handler
}

func (w *wrapper) Apply(resp http.ResponseWriter, req *http.Request, next Next) error {
	w.handler.ServeHTTP(resp, req)
	return next()
}
