// Package eventual provides values that eventually have a value.
package eventual

import (
	"sync"
	"sync/atomic"
	"time"
)

const (
	FALSE = 0
	TRUE  = 1
)

// Value is an eventual value, meaning that callers wishing to access the value
// block until the value is available.
type Value interface {
	// Set sets this Value to the given val.
	Set(val interface{})

	// Get gets the value, blocks until timeout for a value to become available if
	// one isn't immediately available.
	Get(timeout time.Duration) (interface{}, bool)
}

// Getter is a functional interface for the Value.Get function
type Getter func(time.Duration) (interface{}, bool)

type value struct {
	val      atomic.Value
	wg       sync.WaitGroup
	updates  chan interface{}
	gotFirst int32
}

// NewValue creates a new Value.
func NewValue() Value {
	v := &value{updates: make(chan interface{})}
	// Start off by incrementing the WaitGroup by 1 to indicate that we haven't
	// gotten the first value yet.
	v.wg.Add(1)
	go v.processUpdates()
	return v
}

// DefaultGetter builds a Getter that always returns the supplied value.
func DefaultGetter(val interface{}) Getter {
	return func(time.Duration) (interface{}, bool) {
		return val, true
	}
}

func (v *value) Set(val interface{}) {
	v.updates <- val
}

func (v *value) processUpdates() {
	for val := range v.updates {
		v.val.Store(val)
		if v.gotFirst == FALSE {
			// Signal to blocking callers that we have the first value
			v.wg.Done()
			v.gotFirst = TRUE
		}
	}
}

func (v *value) Get(timeout time.Duration) (interface{}, bool) {
	if atomic.LoadInt32(&v.gotFirst) == TRUE {
		// Short-cut used once value has been set, to avoid extra goroutine
		return v.val.Load(), true
	}

	valCh := make(chan interface{})
	go func() {
		v.wg.Wait()
		valCh <- v.val.Load()
	}()

	select {
	case val := <-valCh:
		return val, true
	case <-time.After(timeout):
		return nil, false
	}
}
