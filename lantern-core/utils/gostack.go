package utils

import (
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
// Returned errors always carry a frozen, valid-UTF-8 message before crossing
// back into gomobile's objc bridge. The bridge wraps non-nil Go errors as a
// Universeerror whose initWithRef builds
// `@{NSLocalizedDescriptionKey: [self error]}`; [self error] calls back into
// Go, and the result reaches [NSString initWithBytesNoCopy: ... encoding:UTF8],
// which returns nil for invalid UTF-8 (a gzipped 404 page, a binary blob from
// an upstream LB). Inserting that nil into the dictionary literal aborts the
// app with "attempt to insert nil object from objects[0]".
//
// Because the bridge calls Error() itself rather than reusing anything checked
// here, validating a message and then returning the callee's error would only
// hold for an Error() that answers identically every time. The wrapper is
// therefore unconditional: it is the frozen message, not the check, that makes
// this safe by construction.
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

// sanitizedError presents a bridge-safe message while leaving the original
// error reachable. Replacing the error outright would strip its type and wrap
// chain, silently breaking every errors.Is and errors.As on the far side of a
// gomobile-exported call — the bridge only ever reads Error(), so there is no
// reason to pay that price.
type sanitizedError struct {
	msg string
	err error
}

func (e *sanitizedError) Error() string { return e.msg }
func (e *sanitizedError) Unwrap() error { return e.err }

func sanitizeForGomobile(err error) (safe error) {
	if err == nil {
		return nil
	}
	// Error() is callee-supplied and runs here, on the cgo-callback goroutine,
	// outside the recover that guards fn. An interface holding a typed nil
	// pointer is non-nil but derefs on the call, and an unrecovered panic in
	// the helper whose job is to keep the bridge safe would take the process
	// down on the way out.
	defer func() {
		if r := recover(); r != nil {
			slog.Error("panic formatting error for gomobile", "panic", r, "stack", string(debug.Stack()))
			safe = &sanitizedError{msg: "unknown error"}
		}
	}()
	msg := err.Error()
	if !utf8.ValidString(msg) {
		msg = strings.ToValidUTF8(msg, "?")
	}
	// Not for the bridge's sake — go_seq_to_objc_string returns @"" for an
	// empty message and never reaches initWithBytesNoCopy. An error whose
	// text is blank is just useless to whoever reads the crash report.
	if msg == "" {
		msg = "unknown error"
	}
	return &sanitizedError{msg: msg, err: err}
}
