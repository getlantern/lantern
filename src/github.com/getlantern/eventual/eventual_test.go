package eventual

import (
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

const (
	concurrency = 200
)

func TestSingle(t *testing.T) {
	goroutines := runtime.NumGoroutine()
	v := NewValue()
	go func() {
		time.Sleep(20 * time.Millisecond)
		v.Set("hi")
	}()

	r, ok := v.Get(10 * time.Millisecond)
	assert.False(t, ok, "Get with short timeout should have timed out")

	r, ok = v.Get(20 * time.Millisecond)
	assert.True(t, ok, "Get with longer timeout should have succeed")
	assert.Equal(t, "hi", r, "Wrong result")

	v.Stop()
	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, goroutines, runtime.NumGoroutine(), "should not leave goroutine")
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
	goroutines := runtime.NumGoroutine()
	v := NewValue()

	var sets int32 = 0

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

	time.Sleep(50 * time.Millisecond)
	r, ok := v.Get(20 * time.Millisecond)
	assert.True(t, ok, "Get should have succeed")
	assert.Equal(t, "hi", r, "Wrong result")
	assert.Equal(t, concurrency, atomic.LoadInt32(&sets), "Wrong number of successful Sets")

	v.Stop()
	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, goroutines, runtime.NumGoroutine(), "should not leave goroutine")
}
