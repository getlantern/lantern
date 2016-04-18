package eventual

import (
	"runtime"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
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

	v.Close()
	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, goroutines, runtime.NumGoroutine(), "should not leave goroutine")
}

func TestNoSet(t *testing.T) {
	goroutines := runtime.NumGoroutine()
	v := NewValue()

	_, ok := v.Get(10 * time.Millisecond)
	assert.False(t, ok, "Get before setting value should not be okay")

	// Close the value before we've even set anything
	v.Close()
	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, goroutines, runtime.NumGoroutine(), "should not leave goroutine")

	start := time.Now()
	_, ok = v.Get(1 * time.Second)
	delta := time.Now().Sub(start)
	assert.False(t, ok, "Get after closing should not be okay")
	assert.True(t, delta < 10*time.Millisecond, "Get after closing should have returned immediately")
}

func TestHappenAfter(t *testing.T) {
	v := NewValue()
	defer v.Close()
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		time.Sleep(25 * time.Millisecond)
		v.Set("hi")
		wg.Done()
	}()

	go func() {
		v, valid := v.Get(0)
		if assert.True(t, valid, "Get should happen after Set") {
			assert.Equal(t, "hi", v.(string), "Get should get correct value")
		}
		wg.Done()
	}()
	wg.Wait()
}

func TestNoRace(t *testing.T) {
	goroutines := runtime.NumGoroutine()
	v := NewValue()
	var wg sync.WaitGroup
	wg.Add(20)
	for i := 0; i < 10; i++ {
		go func() {
			v.Set("hi")
			wg.Done()
		}()
		go func() {
			v.Close()
			wg.Done()
		}()
	}
	wg.Wait()
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

	time.Sleep(50 * time.Millisecond)
	r, ok := v.Get(20 * time.Millisecond)
	assert.True(t, ok, "Get should have succeed")
	assert.Equal(t, "hi", r, "Wrong result")
	assert.EqualValues(t, concurrency, atomic.LoadInt32(&sets), "Wrong number of successful Sets")

	v.Close()
	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, goroutines, runtime.NumGoroutine(), "should not leave goroutine")
}
