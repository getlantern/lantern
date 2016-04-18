// Package eventual provides values that eventually have a value.
package eventual

import (
	"sync"
	"sync/atomic"
	"time"
)

const (
	intFalse = 0
	intTrue  = 1
)

// Value is an eventual value, meaning that callers wishing to access the value
// block until the value is available.
type Value interface {
	// Set sets this Value to the given val.
	Set(val interface{})

	// Get gets the value, blocks until timeout for a value to become available if
	// one isn't immediately available.
	Get(timeout time.Duration) (interface{}, bool)

	// Stop clears the resources. Get will return immediately with nil value.
	Stop()
}

// Getter is a functional interface for the Value.Get function
type Getter func(time.Duration) (interface{}, bool)

type value struct {
	val       atomic.Value
	wg        sync.WaitGroup
	muUpdates sync.RWMutex
	updates   chan interface{}
	gotFirst  int32
	stopped   int32
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
	// Prevent sending on closed channel
	if atomic.LoadInt32(&v.stopped) == intFalse {
		v.muUpdates.RLock()
		v.updates <- val
		v.muUpdates.RUnlock()
	}
}

func (v *value) processUpdates() {
	for val := range v.updates {
		v.val.Store(val)
		if v.gotFirst == intFalse {
			// Signal to blocking callers that we have the first value
			v.wg.Done()
			atomic.StoreInt32(&v.gotFirst, intTrue)
		}
	}
	// Ensure Get() to return when Stop() is called
	if atomic.LoadInt32(&v.gotFirst) == intFalse {
		v.wg.Done()
	}
}

func (v *value) Stop() {
	// Prevent closing multiple times
	if atomic.CompareAndSwapInt32(&v.stopped, intFalse, intTrue) {
		v.muUpdates.Lock()
		close(v.updates)
		v.muUpdates.Unlock()
	}
}

// Get waits the value to be set and returns it, or returns nil if times out or
// Stop() is called. valid will be false in latter case.
// TODO: Get should happen after Set if no timeout provided.
func (v *value) Get(timeout time.Duration) (ret interface{}, valid bool) {
	if atomic.LoadInt32(&v.gotFirst) == intTrue {
		// Short-cut used once value has been set, to avoid extra goroutine
		return v.val.Load(), true
	}

	// Make it buffered so if the caller no longer receives on the channel, we
	// can still exit the goroutine.
	valCh := make(chan interface{}, 1)
	go func() {
		v.wg.Wait()
		valCh <- v.val.Load()
	}()
	select {
	case val := <-valCh:
		if val == nil { // when Stop() is called before value is set
			return nil, false
		}
		return val, true
	case <-time.After(timeout):
		return nil, false
	}
}
