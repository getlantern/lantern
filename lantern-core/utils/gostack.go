package utils

import (
	"errors"
	"fmt"
	"log/slog"
	"runtime/debug"
	"strings"
	"unicode/utf8"
)

// RunOffCgoStack executes fn on a new goroutine and returns its result.
// A new goroutine is spawned per call; there is no persistent worker.
//
// Gomobile-exported functions run on a CGo callback stack whose memory isn't
// covered by the GC heap bitmap. When the gomobile-generated wrapper copies Go
// pointer-containing return values to the C thread stack, bulkBarrierPreWrite
// can panic. Running the body on a real Go goroutine avoids this entirely.
//
// If fn panics, the panic is recovered and a zero value + error are returned
// instead of blocking the caller forever.
//
// Returned errors are normalized to a plain *errorString with a guaranteed
// non-empty, valid-UTF-8 message before crossing back into gomobile's
// objc bridge. The bridge wraps non-nil Go errors as a Universeerror whose
// initWithRef calls [NSString initWithBytesNoCopy: ... encoding:UTF8] on the
// raw error bytes; that returns nil for invalid UTF-8 (e.g. a gzipped 404
// page, or a binary blob from an upstream LB), and the dictionary literal
// `@{NSLocalizedDescriptionKey: nil}` then aborts the app with
// "attempt to insert nil object from objects[0]". Sanitizing here means every
// gomobile-exported function that funnels through RunOffCgoStack is safe by
// construction, regardless of what shape of error its callee returns.
func RunOffCgoStack[T any](fn func() (T, error)) (T, error) {
	type result struct {
		val T
		err error
	}
	ch := make(chan result, 1)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				slog.Error("panic in RunOffCgoStack", "panic", r, "stack", string(debug.Stack()))
				var zero T
				ch <- result{val: zero, err: fmt.Errorf("panic: %v", r)}
			}
		}()
		v, err := fn()
		ch <- result{val: v, err: err}
	}()
	r := <-ch
	return r.val, sanitizeForGomobile(r.err)
}

func sanitizeForGomobile(err error) error {
	if err == nil {
		return nil
	}
	msg := err.Error()
	if !utf8.ValidString(msg) {
		msg = strings.ToValidUTF8(msg, "?")
	}
	if msg == "" {
		msg = "unknown error"
	}
	return errors.New(msg)
}
