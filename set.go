// Package set provides both threadsafe and non-threadsafe implementations of
// a generic set data structure. In the threadsafe set, safety encompasses all
// operations on one set. Operations on multiple sets are consistent in that
// the elements of each set used was valid at exactly one point in time
// between the start and the end of the operation.
package set

// Interface describing a Set. Sets are an unordered, unique list of values.
type Interface interface {
	New(items ...interface{}) Interface
	Add(items ...interface{})
	Remove(items ...interface{})
	Pop() interface{}
	Has(items ...interface{}) bool
	Size() int
	Clear()
	IsEmpty() bool
	IsEqual(s Interface) bool
	IsSubset(s Interface) bool
	IsSuperset(s Interface) bool
	Each(func(interface{}) bool)
	String() string
	List() []interface{}
	Copy() Interface
	Merge(s Interface)
	Separate(s Interface)
}

// helpful to not write everywhere struct{}{}
var keyExists = struct{}{}

// Union is the merger of multiple sets. It returns a new set with all the
// elements present in all the sets that are passed. If no items are passed,
// an empty set is returned.
//
// The dynamic type of the returned set is determined by the first passed set's
// implementation of the New() method.
func Union(sets ...Interface) Interface {
	if len(sets) == 0 {
		return New()
	}

	u := sets[0].New()
	for _, set := range sets {
		set.Each(func(item interface{}) bool {
			u.Add(item)
			return true
		})
	}

	return u
}

// Difference returns a new set which contains items which are in in the first
// set but not in the others. Unlike the Difference() method you can use this
// function seperatly with multiple sets. If no items are passed an empty set
// is returned.
func Difference(sets ...Interface) Interface {
	if len(sets) == 0 {
		return New()
	}

	s := sets[0].Copy()
	for _, set := range sets[1:] {
		s.Separate(set) // seperate is thread safe
	}
	return s
}

// Intersection returns a new set which contains items which is in both s and t.
func Intersection(s Interface, t Interface) Interface {
	u := s.Copy()
	u.Separate(Difference(u, t))
	return u
}

// SymmetricDifference returns a new set which s is the difference of items which are in
// one of either, but not in both.
func SymmetricDifference(s Interface, t Interface) Interface {
	u := Difference(s, t)
	v := Difference(t, s)
	return Union(u, v)
}

// StringSlice is a helper function that returns a slice of strings of s. If
// the set contains mixed types of items only items of type string are returned.
func StringSlice(s Interface) []string {
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
func IntSlice(s Interface) []int {
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
