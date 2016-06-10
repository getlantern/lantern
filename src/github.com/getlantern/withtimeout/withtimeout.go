// package withtimeout provides functionality for performing operations with
// a timeout.
package withtimeout

import (
	"time"

	"github.com/getlantern/ops"
)

const (
	timeoutErrorString = "withtimeout: Operation timed out"
)

type timeoutError struct{}

func (timeoutError) Error() string { return timeoutErrorString }

// Do executes the given fn and returns either the result of executing it or an
// error if fn did not complete within timeout. If execution timed out, timedOut
// will be true.
func Do(timeout time.Duration, fn func() (interface{}, error)) (result interface{}, timedOut bool, err error) {
	resultCh := make(chan *resultWithError, 1)

	ops.Go(func() {
		result, err := fn()
		resultCh <- &resultWithError{result, err}
	})

	select {
	case <-time.After(timeout):
		return nil, true, timeoutError{}
	case rwe := <-resultCh:
		return rwe.result, false, rwe.err
	}
}

type resultWithError struct {
	result interface{}
	err    error
}
