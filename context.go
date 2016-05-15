package context

import (
	"sync"
)

var (
	contexts = make(map[uint64]*Context)

	allmx sync.RWMutex
)

// Map is a map of key->value pairs
type Map map[string]interface{}

// Context is a context containing key->value pairs
type Context struct {
	id      uint64
	stack   []Map
	current Map
	initial Map
	mx      sync.RWMutex
}

// Enter enters a new level on the current Context stack, creating a new Context
// if necessary.
func Enter() *Context {
	id := curGoroutineID()
	allmx.Lock()
	c := contexts[id]
	if c == nil {
		c = makeContext(id, nil)
		contexts[id] = c
	}
	allmx.Unlock()
	return c.Enter()
}

// Enter enters a new level on this Context stack.
func (c *Context) Enter() *Context {
	c.mx.Lock()
	c.current = make(map[string]interface{})
	c.stack = append(c.stack, c.current)
	c.mx.Unlock()
	return c
}

// Go starts the given function on a new goroutine using a copy of the values
// from the original context.
func (c *Context) Go(fn func()) {
	initial := c.AsMap()
	go func() {
		id := curGoroutineID()
		c := makeContext(id, initial)
		allmx.Lock()
		contexts[id] = c
		allmx.Unlock()
		fn()
		// Clean up the context
		allmx.Lock()
		delete(contexts, id)
		allmx.Unlock()
	}()
}

// Go starts the given function on a new goroutine but sharing the context of
// the current goroutine (if it has one).
func Go(fn func()) {
	c := currentContext()
	if c != nil {
		c.Go(fn)
	} else {
		go fn()
	}
}

func makeContext(id uint64, initial Map) *Context {
	return &Context{
		id:      id,
		stack:   make([]Map, 0),
		initial: initial,
	}
}

// Exit exits the current level on this Context stack.
func (c *Context) Exit() {
	c.mx.Lock()
	if len(c.stack) > 0 {
		if len(c.stack) == 1 {
			// Last level, remove Context
			allmx.Lock()
			delete(contexts, c.id)
			allmx.Unlock()
		} else {
			c.current = c.stack[len(c.stack)-1]
		}
		c.stack = c.stack[:len(c.stack)-1]
	}
	c.mx.Unlock()
}

// Put puts a key->value pair into the current level of the context stack.
func (c *Context) Put(key string, value interface{}) *Context {
	c.mx.Lock()
	c.current[key] = value
	c.mx.Unlock()
	return c
}

// Read reads all values on the context stack, starting at the current level and
// ascending. Duplicated keys at higher levels are not read.
func (c *Context) Read(cb func(key string, value interface{})) {
	c.mx.RLock()
	if len(c.stack) == 0 {
		return
	}
	knownKeys := make(Map, 0)
	for i := len(c.stack) - 1; i >= -1; i-- {
		var m Map
		if i == -1 {
			m = c.initial
		} else {
			m = c.stack[i]
		}
		if m != nil {
			for key, value := range m {
				_, alreadyRead := knownKeys[key]
				if !alreadyRead {
					cb(key, value)
					knownKeys[key] = nil
				}
			}
		}
	}
	c.mx.RUnlock()
}

// Read calls Read() on the Context stack associated with the current goroutine.
func Read(cb func(key string, value interface{})) {
	c := currentContext()
	if c != nil {
		c.Read(cb)
	}
}

// AsMap returns a map containing all values along the stack.
func (c *Context) AsMap() Map {
	result := make(Map)
	c.Read(func(key string, value interface{}) {
		result[key] = value
	})
	return result
}

// AsMap returns a map containing all values along the stack.
func AsMap() Map {
	c := currentContext()
	if c == nil {
		return make(Map)
	}
	return c.AsMap()
}

func currentContext() *Context {
	id := curGoroutineID()
	allmx.RLock()
	c := contexts[id]
	allmx.RUnlock()
	return c
}
