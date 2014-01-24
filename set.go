// Package set provides both threadsafe and non-threadsafe implementations of
// a generic set data structure.

// In the threadsafe set, safety encompasses all operations on one set.
// Operations on multiple sets are consistent in that the elements
// of each set used was valid at exactly one point in time between the
// start and the end of the operation.
package set

// Interface describing a Set. Sets are an unordered, unique list of values.
type Interface interface {
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
	Union(s Interface) Interface
	Merge(s Interface)
	Separate(s Interface)
	Intersection(s Interface) Interface
	Difference(s Interface) Interface
	SymmetricDifference(s Interface) Interface
	StringSlice() []string
	IntSlice() []int
}

// helpful to not write everywhere struct{}{}
var keyExists = struct{}{}

// Union is the merger of multiple sets. It returns a new set with the
// element in combined in all sets that are passed. Unlike the Union() method
// you can use this function seperatly with multiple sets. If no items are
// passed an empty set is returned.
func Union(sets ...Interface) Interface {
	u := New()
	for _, set := range sets {
		set.Each(func(item interface{}) bool {
			u.m[item] = keyExists
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
