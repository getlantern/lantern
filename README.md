# Goset [![Build Status](https://travis-ci.org/fatih/goset.png)](https://travis-ci.org/fatih/goset) [![Clone in Koding](http://kbutton.org/clone.png)](http://kbutton.org/fatih/goset)

Goset is a basic and simple, hash-based, *thread safe*,  **Set** data structure
implementation in Go. The thread safety encompasses all operations on one set.
Operations on multiple sets are consistent in that the elements of each set
used was valid at exactly one point in time between the start and the end of
the operation. Because it's thread safe, you can use it concurrently with your
goroutines.

For usage see examples below or look at godoc: [Goset godoc](http://godoc.org/github.com/fatih/goset)

## Install

```bash
go get github.com/fatih/goset
```

## Examples

#### Initialization of a new Set

```go

// create a set with zero items
set := goset.New()

// ... or with some initial values 
set := goset.New("istanbul", "frankfurt", 30.123, "san francisco", 1234)

```

#### Basic Operations

```go
// add items
set.Add("istanbul")
set.Add("istanbul") // nothing happens if you add duplicate item

// add multiple items
set.Add("ankara", "san francisco", 3.14)

// remove item
set.Remove("frankfurt")
set.Remove("frankfurt") // nothing happes if you remove a nonexisting item

// remove multiple items
set.Remove("barcelona", 3.14, "ankara")

// removes an arbitary item and return it
item := set.Pop()

// create a new copy
other := set.Copy() 

// remove all items
set.Clear()

// number of items in the set
len := set.Size()

// return a list of items
items := set.List()

// string representation of set
fmt.Printf("set is %s", set.String())

```

#### Check Operations

```go
// check for set emptiness, returns true if set is empty
set.IsEmpty()

// check for a single item exist
set.Has("istanbul")

// ... or for multiple items. This will return true if all of the items exist.
set.Has("istanbul", "san francisco", 3.14)

// create two sets for the following checks...
s := goset.New("1", "2", "3", "4", "5")
t := goset.New("1", "2", "3")


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
a := goset.New("ankara", "berlin", "san francisco")
b := goset.New("frankfurt", "berlin")

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
a := goset.New("1", "2", "3")
b := goset.New("3", "4", "5")
c := goset.New("5", "6", "7")


// creates a new set with items in a, b and c
// [1 2 3 4 5 6 7]
u := goset.Union(a, b, c)

// creates a new set with items in a but not in b and c
// [1 2]
u := goset.Difference(a, b, c)
```

#### Helper methods

The Slice functions below are a convenient way to extract or convert your Set data
into basic data types.


```go
// create a set of mixed types
s := goset.New("ankara", "5", "8", "san francisco", 13, 21)


// convert s into a slice of strings (type is []string)
// [ankara 5 8 san francisco]
t := s.StringSlice()


// u contains a slice of ints (type is []int)
// [13, 21]
u := s.IntSlice()

```

#### Concurrent safe usage

Below is an example of a concurrent way that uses goset. We call ten functions
concurrently and wait until they are finished. It basically creates a new
string for each goroutine and adds it to our set.

```go
package main

import (
	"fmt"
	"github.com/fatih/goset"
	"strconv"
	"sync"
)

func main() {
	var wg sync.WaitGroup // this is just for waiting until all goroutines finish

	// Initialize our Set
	s := goset.New()

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

## License

The MIT License (MIT) - see LICENSE.md for more details

