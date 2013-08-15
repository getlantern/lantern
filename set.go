// Goset is a thread safe SET data structure implementation
// The thread safety encompasses all operations on one set.
// Operations on multiple sets are consistent in that the elements
// of each set used was valid at exactly one point in time between the
// start and the end of the operation.
package goset

import (
	"fmt"
	"strings"
	"sync"
)

type Set struct {
	m map[interface{}]struct{} // struct{} doesn't take up space
	l sync.RWMutex             // we name it because we don't want to expose it
}

// helpful to not write everywhere struct{}{}
var keyExists = struct{}{}

// New creates and initialize a new Set. It's accept a variable number of
// arguments to populate the initial set. If nothing passed a Set with zero
// size is created.
func New(items ...interface{}) *Set {
	s := &Set{
		m: make(map[interface{}]struct{}),
	}

	s.Add(items...)
	return s
}

// Add includes the specified items (one or more) to the set. The underlying
// Set s is modified. If passed nothing it silently returns.
func (s *Set) Add(items ...interface{}) {
	if len(items) == 0 {
		return
	}

	s.l.Lock()
	for _, item := range items {
		s.m[item] = keyExists
	}
	s.l.Unlock()
}

// Remove deletes the specified items from the set.  The underlying Set s is
// modified. If passed nothing it silently returns.
func (s *Set) Remove(items ...interface{}) {
	if len(items) == 0 {
		return
	}
	s.l.Lock()
	for _, item := range items {
		delete(s.m, item)
	}
	s.l.Unlock()
}

// Has looks for the existence of items passed. It returns false if nothing is
// passed. For multiple items it returns true only if all of  the items exist.
func (s *Set) Has(items ...interface{}) bool {
	// assume checked for empty item, which not exist
	if len(items) == 0 {
		return false
	}

	s.l.RLock()
	has := true
	for _, item := range items {
		if _, has = s.m[item]; !has {
			break
		}
	}
	s.l.RUnlock()
	return has
}

// Size returns the number of items in a set.
func (s *Set) Size() int {
	s.l.RLock()
	l := len(s.m)
	s.l.RUnlock()
	return l
}

// Clear removes all items from the set.
func (s *Set) Clear() {
	s.l.Lock()
	s.m = make(map[interface{}]struct{})
	s.l.Unlock()
}

// IsEmpty reports whether the Set is empty.
func (s *Set) IsEmpty() bool {
	return s.Size() == 0
}

// IsEqual test whether s and t are the same in size and have the same items.
func (s *Set) IsEqual(t *Set) bool {
	s.l.RLock()
	t.l.RLock()
	equal := true

	if equal = len(s.m) == len(t.m); equal {
		for item := range s.m {
			if _, equal = t.m[item]; !equal {
				break
			}
		}
	}

	t.l.RUnlock()
	s.l.RUnlock()
	return equal
}

// IsSubset tests whether t is a subset of s.
func (s *Set) IsSubset(t *Set) bool {
	s.l.RLock()
	t.l.RLock()
	subset := true

	for item := range t.m {
		if _, subset = s.m[item]; !subset {
			break
		}
	}

	t.l.RUnlock()
	s.l.RUnlock()
	return subset
}

// IsSuperset tests whether t is a superset of s.
func (s *Set) IsSuperset(t *Set) bool {
	return t.IsSubset(s)
}

// String returns a string representation of s
func (s *Set) String() string {
	t := make([]string, 0, len(s.List()))
	for _, item := range s.List() {
		t = append(t, fmt.Sprintf("%v", item))
	}
	return fmt.Sprintf("[%s]", strings.Join(t, ", "))
}

// List returns a slice of all items. There is also StringSlice() and
// IntSlice() methods for returning slices of type string or int.
func (s *Set) List() []interface{} {
	s.l.RLock()

	list := make([]interface{}, 0, len(s.m))

	for item := range s.m {
		list = append(list, item)
	}

	s.l.RUnlock()
	return list
}

// Copy returns a new Set with a copy of s.
func (s *Set) Copy() *Set {
	return New(s.List()...)
}

// Union is the merger of two sets. It returns a new set with the element in s
// and t combined. It doesn't modify s. Use Merge() if  you want to change the
// underlying set s.
func (s *Set) Union(t *Set) *Set {
	u := s.Copy()
	u.Merge(t)
	return u
}

// Merge is like Union, however it modifies the current set it's applied on
// with the given t set.
func (s *Set) Merge(t *Set) {
	s.l.Lock()
	t.l.RLock()
	for item := range t.m {
		s.m[item] = keyExists
	}
	t.l.RUnlock()
	s.l.Unlock()
}

// Separate removes the set items containing in t from set s. Please aware that
// it's not the opposite of Merge.
func (s *Set) Separate(t *Set) {
	s.Remove(t.List()...)
}

// Intersection returns a new set which contains items which is in both s and t.
func (s *Set) Intersection(t *Set) *Set {
	u := s.Copy()
	u.Separate(u.Difference(t))
	return u
}

// Intersection returns a new set which contains items which are both s but not in t.
func (s *Set) Difference(t *Set) *Set {
	u := s.Copy()
	u.Separate(t)
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
