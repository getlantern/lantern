// Goset is a thread safe SET data structure implementation
package goset

import "sync"

type Set struct {
	m map[interface{}]bool
	sync.RWMutex
}

// New creates and initialize a new Set.
func New() *Set {
	return &Set{
		m: make(map[interface{}]bool),
	}
}

// Add includes the specified item to the set
func (s *Set) Add(item interface{}) {
	s.Lock()
	defer s.Unlock()
	s.m[item] = true
}

// AddAll merge the specified set to the s
func (s *Set) AddAll(set *Set) {
	for _, item := range set.List() {
		s.Add(item)
	}
}

// Remove deletes the specified item from the set
func (s *Set) Remove(item interface{}) {
	s.Lock()
	defer s.Unlock()
	delete(s.m, item)
}

// Has looks for the existence of an item
func (s *Set) Has(item interface{}) bool {
	s.RLock()
	defer s.RUnlock()
	_, ok := s.m[item]
	return ok
}

// Size returns the number of items in a set.
func (s *Set) Size() int {
	s.RLock()
	defer s.RUnlock()
	return len(s.m)
}

// Clear removes all items from the set
func (s *Set) Clear() {
	s.Lock()
	defer s.Unlock()
	s.m = make(map[interface{}]bool)
}

// IsEmpty checks for emptiness of the set
func (s *Set) IsEmpty() bool {
	if s.Size() == 0 {
		return true
	}
	return false
}

// List returns a slice of all items
func (s *Set) List() []interface{} {
	s.RLock()
	defer s.RUnlock()
	list := make([]interface{}, 0)
	for item := range s.m {
		list = append(list, item)
	}
	return list
}
