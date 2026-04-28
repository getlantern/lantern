package utils

import (
	"fmt"
	"log/slog"
	"runtime/debug"
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
	return r.val, r.err
}
