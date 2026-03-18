package utils

import (
	"fmt"
	"log/slog"
	"runtime/debug"
)

// RunOnGoStack executes fn on a dedicated goroutine and returns its result.
// This is needed when Go code is called from a CGo callback stack (e.g. via
// gomobile): pointer-rich types trigger GC write barrier panics because the
// GC heap bitmap does not cover the C stack. Running the work on a proper Go
// goroutine stack avoids the issue.
//
// If fn panics, the panic is recovered and a zero value + error are returned
// instead of blocking the caller forever.
func RunOnGoStack[T any](fn func() (T, error)) (T, error) {
	type result struct {
		val T
		err error
	}
	ch := make(chan result, 1)
	go func() {
		defer func() {
			if r := recover(); r != nil {
				slog.Error("panic in RunOnGoStack", "panic", r, "stack", string(debug.Stack()))
				var zero T
				ch <- result{val: zero, err: fmt.Errorf("panic: %v", r)}
			}
		}()
		v, err := fn()
		ch <- result{val: v, err: err}
	}()
	r := <-ch
	return r.val, r.err
}
