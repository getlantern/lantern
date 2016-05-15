package context

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestStack(t *testing.T) {
	c := Enter()
	c.Put("a", 1)
	Enter().
		Put("b", 2).
		Put("c", 3)
	c.Enter().
		Put("c", 4).
		Put("d", 5)

	var assertMutex sync.Mutex
	assertContents := func(expected Map) {
		m := AsMap()
		assertMutex.Lock()
		assert.Equal(t, expected, m)
		assertMutex.Unlock()
	}

	var wg sync.WaitGroup
	wg.Add(1)
	Go(func() {
		Enter().Put("e", 6)
		assertContents(Map{
			"a": 1,
			"b": 2,
			"c": 4,
			"d": 5,
			"e": 6,
		})
		wg.Done()
	})
	wg.Wait()

	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 4,
		"d": 5,
	})

	c.Exit()
	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 3,
	})

	c.Exit()
	assertContents(Map{
		"a": 1,
	})

	c.Exit()
	assertContents(Map{})

	// Exit again, just for good measure
	c.Exit()
	assertContents(Map{})

	// Spawn a goroutine with no existing contexts
	wg.Add(1)
	Go(func() {
		Enter().Put("f", 7)
		assertContents(Map{
			"f": 7,
		})
		wg.Done()
	})
	wg.Wait()
}

func BenchmarkPut(b *testing.B) {
	c := Enter()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		c.Put("key", "value")
	}
}

func BenchmarkAsMapCheap(b *testing.B) {
	c := Enter().Put("a", 1).Put("b", 2)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		c.AsMap()
	}
}

func BenchmarkAsMapExpensive(b *testing.B) {
	Enter().Put("a", 1).Put("b", 2)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		AsMap()
	}
}
