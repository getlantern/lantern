# Set [![GoDoc](https://godoc.org/github.com/fatih/set?status.png)](http://godoc.org/github.com/fatih/set) [![Build Status](https://travis-ci.org/fatih/set.png)](https://travis-ci.org/fatih/set)

Set is a basic and simple, hash-based, **Set** data structure implementation
in Go (Golang).

Set provides both threadsafe and non-threadsafe implementations of a generic
set data structure. The thread safety encompasses all operations on one set.
Operations on multiple sets are consistent in that the elements of each set
used was valid at exactly one point in time between the start and the end of
the operation. Because it's thread safe, you can use it concurrently with your
goroutines.

For usage see examples below or click on the godoc badge.

## Install

```bash
go get github.com/fatih/set
```

## Examples

#### Initialization of a new Set

```go

// create a set with zero items
s := set.New()

// ... or with some initial values
s := set.New("istanbul", "frankfurt", 30.123, "san francisco", 1234)

```

#### Basic Operations

```go
// add items
s.Add("istanbul")
s.Add("istanbul") // nothing happens if you add duplicate item

// add multiple items
s.Add("ankara", "san francisco", 3.14)

// remove item
s.Remove("frankfurt")
s.Remove("frankfurt") // nothing happes if you remove a nonexisting item

// remove multiple items
s.Remove("barcelona", 3.14, "ankara")

// removes an arbitary item and return it
item := s.Pop()

// create a new copy
other := s.Copy()

// remove all items
s.Clear()

// number of items in the set
len := s.Size()

// return a list of items
items := s.List()

// string representation of set
fmt.Printf("set is %s", s.String())

```

#### Check Operations

```go
// check for set emptiness, returns true if set is empty
s.IsEmpty()

// check for a single item exist
s.Has("istanbul")

// ... or for multiple items. This will return true if all of the items exist.
s.Has("istanbul", "san francisco", 3.14)

// create two sets for the following checks...
s := s.New("1", "2", "3", "4", "5")
t := s.New("1", "2", "3")


// check if they are the same
if !s.IsEqual(t) {
    fmt.Println("s is not equal to t")
}

// if s contains all elements of t
if s.IsSubset(t) {
	fmt.Println("t is a subset of s")
}

// ... or if s is a superset of t
if t.IsSuperset(s) {
	fmt.Println("s is a superset of t")
}


```

#### Set Operations


```go
// let us initialize two sets with some values
a := set.New("ankara", "berlin", "san francisco")
b := set.New("frankfurt", "berlin")

// creates a new set with the items in a and b combined.
// [frankfurt, berlin, ankara, san francisco]
c := a.Union(b)

// contains items which is in both a and b
// [berlin]
c := a.Intersection(b)

// contains items which are in a but not in b
// [ankara, san francisco]
c := a.Difference(b)

// contains items which are in one of either, but not in both.
// [frankfurt, ankara, san francisco]
c := a.SymmetricDifference(b)

```

```go
// like Union but saves the result back into a.
a.Merge(b)

// removes the set items which are in b from a and saves the result back into a.
a.Separate(b)

```

#### Multiple Set Operations

```go
a := set.New("1", "2", "3")
b := set.New("3", "4", "5")
c := set.New("5", "6", "7")


// creates a new set with items in a, b and c
// [1 2 3 4 5 6 7]
u := set.Union(a, b, c)

// creates a new set with items in a but not in b and c
// [1 2]
u := set.Difference(a, b, c)
```

#### Helper methods

The Slice functions below are a convenient way to extract or convert your Set data
into basic data types.


```go
// create a set of mixed types
s := set.New("ankara", "5", "8", "san francisco", 13, 21)


// convert s into a slice of strings (type is []string)
// [ankara 5 8 san francisco]
t := s.StringSlice()


// u contains a slice of ints (type is []int)
// [13, 21]
u := s.IntSlice()

```

#### Concurrent safe usage

Below is an example of a concurrent way that uses set. We call ten functions
concurrently and wait until they are finished. It basically creates a new
string for each goroutine and adds it to our set.

```go
package main

import (
	"fmt"
	"github.com/fatih/set"
	"strconv"
	"sync"
)

func main() {
	var wg sync.WaitGroup // this is just for waiting until all goroutines finish

	// Initialize our Set
	s := set.New()

	// Add items concurrently (item1, item2, and so on)
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(i int) {
			item := "item" + strconv.Itoa(i)
			fmt.Println("adding", item)
			s.Add(item)
			wg.Done()
		}(i)
	}

	// Wait until all concurrent calls finished and print our set
	wg.Wait()
	fmt.Println(s)
}
```


## Credits

 * [Fatih Arslan](https://github.com/fatih)
 * [Arne Hormann](https://github.com/arnehormann)
 * [Sam Boyer](https://github.com/sdboyer)

## License

The MIT License (MIT) - see LICENSE.md for more details

