package eventual

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/grtrack"
	"github.com/stretchr/testify/assert"
)

const (
	concurrency = 200
)

func TestSingle(t *testing.T) {
	goroutines := grtrack.Start()
	v := NewValue()
	go func() {
		time.Sleep(20 * time.Millisecond)
		v.Set("hi")
	}()

	r, ok := v.Get(0)
	assert.False(t, ok, "Get with no timeout should have failed")

	r, ok = v.Get(10 * time.Millisecond)
	assert.False(t, ok, "Get with short timeout should have timed out")

	r, ok = v.Get(-1)
	assert.True(t, ok, "Get with really long timeout should have succeeded")
	assert.Equal(t, "hi", r, "Wrong result")

	// Set a different value
	v.Set("bye")
	r, ok = v.Get(0)
	assert.True(t, ok, "Subsequent get with no timeout should have succeeded")
	assert.Equal(t, "bye", r, "Value should have changed")

	goroutines.CheckAfter(t, 50*time.Millisecond)
}

func TestNoSet(t *testing.T) {
	goroutines := grtrack.Start()
	v := NewValue()

	_, ok := v.Get(10 * time.Millisecond)
	assert.False(t, ok, "Get before setting value should not be okay")

	goroutines.CheckAfter(t, 50*time.Millisecond)
}

func TestCancelImmediate(t *testing.T) {
	v := NewValue()
	go func() {
		time.Sleep(10 * time.Millisecond)
		v.Cancel()
	}()

	_, ok := v.Get(200 * time.Millisecond)
	assert.False(t, ok, "Get after cancel should have failed")
}

func TestCancelAfterSet(t *testing.T) {
	v := NewValue()
	v.Set(5)
	r, ok := v.Get(10 * time.Millisecond)
	assert.True(t, ok, "Get before cancel should have succeeded")
	assert.Equal(t, 5, r, "Get got wrong value before cancel")

	v.Cancel()
	r, ok = v.Get(0)
	assert.True(t, ok, "Get after cancel should have succeeded")
	assert.Equal(t, 5, r, "Get got wrong value after cancel")

	v.Set(10)
	r, _ = v.Get(0)
	assert.Equal(t, 5, r, "Set after cancel should have no effect")
}

func BenchmarkGet(b *testing.B) {
	v := NewValue()
	go func() {
		time.Sleep(20 * time.Millisecond)
		v.Set("hi")
	}()

	for i := 0; i < b.N; i++ {
		v.Get(20 * time.Millisecond)
	}
}

func TestConcurrent(t *testing.T) {
	goroutines := grtrack.Start()
	v := NewValue()

	var sets int32

	go func() {
		var wg sync.WaitGroup
		wg.Add(1)
		// Do some concurrent setting to make sure that it works
		for i := 0; i < concurrency; i++ {
			go func() {
				// Wait for waitGroup so that all goroutines run at basically the same
				// time.
				wg.Wait()
				v.Set("hi")
				atomic.AddInt32(&sets, 1)
			}()
		}
		wg.Done()
	}()

	for i := 0; i < concurrency; i++ {
		go func() {
			r, ok := v.Get(200 * time.Millisecond)
			assert.True(t, ok, "Get should have succeed")
			assert.Equal(t, "hi", r, "Wrong result")
		}()
	}

	goroutines.CheckAfter(t, 50*time.Millisecond)
	assert.EqualValues(t, concurrency, atomic.LoadInt32(&sets), "Wrong number of successful Sets")
}
