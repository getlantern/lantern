package golog

import (
	"bytes"
	"fmt"

	"github.com/getlantern/gls"
	"github.com/oxtoacart/bpool"
)

var (
	// Context provides context for logging calls.
	Context = &ContextManager{}
)

// ContextManager manages context for additional logging information.
type ContextManager struct {
}

// Set sets a key->value pair in the current Context.
func (c *ContextManager) Set(key string, value interface{}) {
	gls.Set(key, value)
}

// SetAll sets multiple key->value paris in the current Context.
func (c *ContextManager) SetAll(values map[string]interface{}) {
	gls.SetValues(gls.Values(values))
}

// Go is a substitute for the built-in go that associates the new Goroutine with
// this Context.
func (c *ContextManager) Go(fn func()) {
	gls.Go(fn)
}

// Clear clears any values in the current Context. It's important to do this to
// prevent memory leaks.
func (c *ContextManager) Clear() {
	gls.Cleanup()
}

func withContextInfo(fn func(contextInfo string)) {
	gls.ReadAll(func(values gls.Values) error {
		contextInfo := ""
		if values != nil && len(values) > 0 {
			buf := bytes.NewBuffer(make([]byte))
			for key, value := range values {
				buf.WriteString(" ")
				buf.WriteString(key)
				buf.WriteString("=")
				fmt.Fprintf(&buf, "%v", value)
			}
			contextInfo = buf.String()
		}
		fn(contextInfo)
		return nil
	})
}
