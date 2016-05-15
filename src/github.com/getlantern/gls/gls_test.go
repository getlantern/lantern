package gls

import (
	"errors"
	"sync"
	"testing"

	"github.com/tylerb/is"
)

func TestGLS(t *testing.T) {
	is := is.New(t)

	Set("key", "value")
	v := Get("key")
	is.NotNil(v)
	is.Equal(v, "value")

	Cleanup()
}

func TestGLSWith(t *testing.T) {
	is := is.New(t)

	With(Values{"key": "value"}, func() {
		v := Get("key")
		is.NotNil(v)
		is.Equal(v, "value")
	})

	v := Get("key")
	is.Nil(v)
}

func TestGLSSetValues(t *testing.T) {
	is := is.New(t)

	Set("key", "value")
	v := Get("key")
	is.NotNil(v)
	is.Equal(v, "value")

	SetValues(Values{"question": "what is the meaning of life", "answer": 42})
	v = Get("key")
	is.Nil(v)

	v = Get("question")
	is.NotNil(v)
	is.Equal(v, "what is the meaning of life")

	v = Get("answer")
	is.NotNil(v)
	is.Equal(v, 42)

	m := GetAll()
	dataLock.RLock()
	gid := curGoroutineID()
	is.Equal(m, data[gid])
	m["new"] = "only in copy"
	is.NotEqual(m, data[gid])
	dataLock.RUnlock()

	e := errors.New("Test Error")
	err := ReadAll(func(values Values) error {
		is.Equal(values, data[gid])
		return e
	})
	is.Equal(err, e)

	Cleanup()
}

func TestGLSGo(t *testing.T) {
	is := is.New(t)

	var wg sync.WaitGroup
	wg.Add(3)

	Set("key", "value")

	Go(func() {
		v := Get("key")
		is.NotNil(v)
		is.Equal(v, "value")
		Go(func() {
			v := Get("key")
			is.NotNil(v)
			is.Equal(v, "value")
			Set("answer", 42)
			Go(func() {
				v := Get("key")
				is.NotNil(v)
				is.Equal(v, "value")
				v = Get("answer")
				is.NotNil(v)
				is.Equal(v, 42)
				wg.Done()
			})
			wg.Done()
		})
		wg.Done()
	})

	v := Get("key")
	is.NotNil(v)
	is.Equal(v, "value")

	wg.Wait()

	Cleanup()
}

func BenchmarkGLSSet(b *testing.B) {
	for i := 0; i < b.N; i++ {
		Set("key", "value")
	}
	Cleanup()
}

func BenchmarkGLSGet(b *testing.B) {
	b.StopTimer()
	Set("key", "value")
	b.StartTimer()
	for i := 0; i < b.N; i++ {
		Get("key")
	}
	Cleanup()
}

func BenchmarkGLSGetAll(b *testing.B) {
	b.StopTimer()
	SetValues(Values{"key": "value", "key2": "othervalue"})
	b.StartTimer()
	for i := 0; i < b.N; i++ {
		GetAll()
	}
	Cleanup()
}

func BenchmarkGID(b *testing.B) {
	for i := 0; i < b.N; i++ {
		curGoroutineID()
	}
}
