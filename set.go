// Goset is a thread safe SET data structure implementation
package goset

import (
	"fmt"
	"strings"
	"sync"
)

type Set struct {
	m map[interface{}]struct{}
	l sync.RWMutex // we name it because we don't want to expose it
}

// New creates and initialize a new Set. It's accept a variable number of
// arguments to populate the initial set. If nothing passed a Set with zero
// size is created.
func New(items ...interface{}) *Set {
	s := &Set{
		m: make(map[interface{}]struct{}), // struct{} doesn't take up space
	}

	for _, item := range items {
		s.Add(item)
	}

	return s
}

// Add includes the specified item to the set.
func (s *Set) Add(item interface{}) {
	s.l.Lock()
	defer s.l.Unlock()
	s.m[item] = struct{}{}
}

// Remove deletes the specified item from the set
func (s *Set) Remove(item interface{}) {
	s.l.Lock()
	defer s.l.Unlock()
	delete(s.m, item)
}

// Has looks for the existence of an item
func (s *Set) Has(item interface{}) bool {
	s.l.RLock()
	defer s.l.RUnlock()
	_, ok := s.m[item]
	return ok
}

// Size returns the number of items in a set.
func (s *Set) Size() int {
	s.l.RLock()
	defer s.l.RUnlock()
	return len(s.m)
}

// Clear removes all items from the set
func (s *Set) Clear() {
	s.l.Lock()
	defer s.l.Unlock()
	s.m = make(map[interface{}]struct{})
}

// IsEmpty checks for emptiness of the set
func (s *Set) IsEmpty() bool {
	if s.Size() == 0 {
		return true
	}
	return false
}

// IsEqual test whether s and t are the same in size and have the same items.
func (s *Set) IsEqual(t *Set) bool {
	if s.Size() != t.Size() {
		return false
	}
	if s.Size() != s.Union(t).Size() {
		return false
	}
	return true
}

// IsSubset tests t is a subset of s.
func (s *Set) IsSubset(t *Set) bool {
	for _, item := range t.List() {
		if !s.Has(item) {
			return false
		}
	}
	return true
}

// IsSuperset tests if t is a superset of s.
func (s *Set) IsSuperset(t *Set) bool {
	return t.IsSubset(s)
}

// String representation of s
func (s *Set) String() string {
	t := make([]string, 0)
	for _, item := range s.List() {
		t = append(t, fmt.Sprintf("%v", item))
	}
	return fmt.Sprintf("[%s]", strings.Join(t, ", "))
}

// List returns a slice of all items
func (s *Set) List() []interface{} {
	s.l.RLock()
	defer s.l.RUnlock()
	list := make([]interface{}, 0)
	for item := range s.m {
		list = append(list, item)
	}
	return list
}

// Copy returns a new Set with a copy of s.
func (s *Set) Copy() *Set {
	return New(s.List()...)
}

// Union is the merger of two sets. It returns a new set with the element in s
// and t combined.
func (s *Set) Union(t *Set) *Set {
	u := New(t.List()...)
	for _, item := range s.List() {
		u.Add(item)
	}
	return u
}

// Merge is like Union, however it modifies the current set it's applied on
// with the given t set.
func (s *Set) Merge(t *Set) {
	for _, item := range t.List() {
		s.Add(item)
	}
}

// Separate removes the set items containing in t from set s. Please aware that
// it's not the opposite of Merge.
func (s *Set) Separate(t *Set) {
	for _, item := range t.List() {
		s.Remove(item)
	}
}

// Intersection returns a new set which contains items which is in both s and t.
func (s *Set) Intersection(t *Set) *Set {
	u := New()
	for _, item := range s.List() {
		if t.Has(item) {
			u.Add(item)
		}
	}
	for _, item := range t.List() {
		if s.Has(item) {
			u.Add(item)
		}
	}
	return u
}

// Intersection returns a new set which contains items which are both s but not in t.
func (s *Set) Difference(t *Set) *Set {
	u := New()
	for _, item := range s.List() {
		if !t.Has(item) {
			u.Add(item)
		}
	}
	return u
}

// Symmetric returns a new set which s is the difference of items  which are in
// one of either, but not in both.
func (s *Set) SymmetricDifference(t *Set) *Set {
	u := s.Difference(t)
	v := t.Difference(s)
	return u.Union(v)
}

// StringSlice is a helper function that returns a slice of strings of s. If
// the set contains mixed types of items only items of type string are returned.
func (s *Set) StringSlice() []string {
	slice := make([]string, 0)
	for _, item := range s.List() {
		v, ok := item.(string)
		if !ok {
			continue
		}

		slice = append(slice, v)
	}
	return slice
}

// IntSlice is a helper function that returns a slice of ints of s. If
// the set contains mixed types of items only items of type int are returned.
func (s *Set) IntSlice() []int {
	slice := make([]int, 0)
	for _, item := range s.List() {
		v, ok := item.(int)
		if !ok {
			continue
		}

		slice = append(slice, v)
	}
	return slice
}
