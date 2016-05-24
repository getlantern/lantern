package context

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestStack(t *testing.T) {
	// Put globals first
	PutGlobal("a", -1) // This will get overriden in specific contexts
	PutGlobal("ga", "i")
	PutGlobalDynamic("gb", func() interface{} { return "ii" })

	// Use a Map as a Contextual
	var contextual = Map{
		"a":          0, // This will override whatever is in specific contexts
		"contextual": "special",
	}

	c := Enter()
	c.Put("a", 1)
	penultimate := Enter().
		Put("b", 2)
	c = Enter().
		PutDynamic("c", func() interface{} { return 4 }).
		PutIfAbsent("d", 5).
		PutIfAbsent("a", 11)

	// Put something in the penultimate context and make sure it doesn't override
	// what's set in the ultimate context
	penultimate.Put("c", 3)

	var assertMutex sync.Mutex
	doAssertContents := func(expected Map, actual Map, scope string) {
		assertMutex.Lock()
		assert.Equal(t, expected, actual, scope)
		assertMutex.Unlock()
	}

	assertContents := func(expected Map) {
		doAssertContents(expected, AsMap(nil, false), "AsMapwith(nil, false)")
		expected["ga"] = "i"
		expected["gb"] = "ii"
		_, exists := expected["a"]
		if !exists {
			expected["a"] = -1
		}
		doAssertContents(expected, AsMap(nil, true), "AsMap(nil, true)")
		expected["a"] = 0
		expected["contextual"] = "special"
		doAssertContents(expected, AsMap(contextual, true), "AsMapWith(contextual, true)")
		delete(expected, "ga")
		delete(expected, "gb")
		doAssertContents(expected, AsMap(contextual, false), "AsMapWith(contextual, false)")
	}

	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 4,
		"d": 5,
	})

	var wg sync.WaitGroup
	wg.Add(1)
	Go(func() {
		defer Enter().Put("e", 6).Exit()
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

	wg.Add(1)
	Go(func() {
		// This goroutine doesn't Exit. Still, we shouldn't leak anything.
		wg.Done()
	})
	wg.Wait()

	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 4,
		"d": 5,
	})

	c = c.Exit()
	assert.NotNil(t, c)
	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 3,
	})

	c = c.Exit()
	assert.NotNil(t, c)
	assertContents(Map{
		"a": 1,
	})

	// Last exit
	assert.Nil(t, c.Exit())
	assertContents(Map{})

	// Exit again, just for good measure
	assert.Nil(t, c.Exit())
	assertContents(Map{})

	// Spawn a goroutine with no existing contexts
	wg.Add(1)
	Go(func() {
		defer Enter().Put("f", 7).Exit()
		assertContents(Map{
			"f": 7,
		})
		wg.Done()
	})
	wg.Wait()

	allmx.RLock()
	assert.Empty(t, contexts, "No contexts should be left")
	allmx.RUnlock()
}

func BenchmarkPut(b *testing.B) {
	c := Enter()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		c.Put("key", "value")
	}
}

func BenchmarkAsMap(b *testing.B) {
	Enter().Put("a", 1).Put("b", 2)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		AsMap(nil, true)
	}
}
