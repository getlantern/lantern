package context

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestStack(t *testing.T) {
	cm := NewManager()
	_cm := cm.(*manager)
	// Put globals first
	cm.PutGlobal("a", -1) // This will get overriden in specific contexts
	cm.PutGlobal("ga", "i")
	cm.PutGlobalDynamic("gb", func() interface{} { return "ii" })

	// Use a Map as a Contextual
	var contextual = Map{
		"a":          0, // This will override whatever is in specific contexts
		"contextual": "special",
	}

	c := cm.Enter()
	c.Put("a", 1)
	penultimate := cm.Enter().
		Put("b", 2)
	c = cm.Enter().
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
		doAssertContents(expected, cm.AsMap(nil, false), "AsMapwith(nil, false)")
		expected["ga"] = "i"
		expected["gb"] = "ii"
		_, exists := expected["a"]
		if !exists {
			expected["a"] = -1
		}
		doAssertContents(expected, cm.AsMap(nil, true), "AsMap(nil, true)")
		expected["a"] = 0
		expected["contextual"] = "special"
		doAssertContents(expected, cm.AsMap(contextual, true), "AsMapWith(contextual, true)")
		delete(expected, "ga")
		delete(expected, "gb")
		doAssertContents(expected, cm.AsMap(contextual, false), "AsMapWith(contextual, false)")
	}

	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 4,
		"d": 5,
	})

	var wg sync.WaitGroup
	wg.Add(1)
	cm.Go(func() {
		defer cm.Enter().Put("e", 6).Exit()
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
	cm.Go(func() {
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

	c.Exit()
	c = _cm.currentContext()
	assert.NotNil(t, c)
	assertContents(Map{
		"a": 1,
		"b": 2,
		"c": 3,
	})

	c.Exit()
	c = _cm.currentContext()
	assert.NotNil(t, c)
	assertContents(Map{
		"a": 1,
	})

	// Last exit
	c.Exit()
	assert.Nil(t, _cm.currentContext())
	assertContents(Map{})

	// Exit again, just for good measure
	c.Exit()
	assert.Nil(t, _cm.currentContext())
	assertContents(Map{})

	// Spawn a goroutine with no existing contexts
	wg.Add(1)
	cm.Go(func() {
		defer cm.Enter().Put("f", 7).Exit()
		assertContents(Map{
			"f": 7,
		})
		wg.Done()
	})
	wg.Wait()

	_cm.allmx.RLock()
	assert.Empty(t, _cm.contexts, "No contexts should be left")
	_cm.allmx.RUnlock()
}

func BenchmarkPut(b *testing.B) {
	cm := NewManager()
	c := cm.Enter()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		c.Put("key", "value")
	}
}

func BenchmarkAsMap(b *testing.B) {
	cm := NewManager()
	cm.Enter().Put("a", 1).Put("b", 2)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cm.AsMap(nil, true)
	}
}
