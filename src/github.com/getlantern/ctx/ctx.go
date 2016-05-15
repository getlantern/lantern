// Package ctx provides the ability to capture contextual information
// and associate it to the current call context, even crossing goroutines.
// It is a veneer around github.com/tylerb/gls.
package ctx

import (
	"bytes"
	"fmt"
	"sort"

	"github.com/getlantern/gls"
)

// Map is a map of values
type Map gls.Values

// Set sets a single key->value pair in the current context.
func Set(key string, value interface{}) {
	gls.Set(key, value)
}

// SetAll sets multiple key->value pairs in the current context.
func SetAll(values Map) {
	gls.AddValues(gls.Values(values))
}

// Go is a substitute for the built-in go that associates the new Goroutine with
// this context.
func Go(fn func()) {
	gls.Go(fn)
}

// Clear clears any values in the current context. It's important to do this to
// prevent memory leaks.
func Clear() {
	gls.Cleanup()
}

// PrintTo prints the contents of the context to the given Buffer as
// key1=value key2=value etc. If there are no values in the context, it prints
// nothing.
func PrintTo(buf *bytes.Buffer) {
	gls.ReadAll(func(values gls.Values) error {
		if values != nil && len(values) > 0 {
			buf.WriteString(" [")
			var keys []string
			for key := range values {
				keys = append(keys, key)
			}
			sort.Strings(keys)
			for i, key := range keys {
				value := values[key]
				if i > 0 {
					buf.WriteString(" ")
				}
				buf.WriteString(key)
				buf.WriteString("=")
				fmt.Fprintf(buf, "%v", value)
			}
			buf.WriteByte(']')
		}
		return nil
	})
}
