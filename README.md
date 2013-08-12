# Goset

Goset is a basic and simple **thread safe** SET data structure implementation in
Go. Because it's thread safe, you can use it concurrently with your goroutines.

For usage see examples below or look at godoc: [Goset godoc](http://godoc.org/github.com/fatih/goset)

## Install

```bash
go get github.com/fatih/goset
```

## Examples


Initialization of a new Set

```go

// create a set with zero items
set := goset.New()

// ... or with some initial values
set := goset.New("istanbul", frankfurt", "san francisco", 1234)

```

Basic Operations

```go
// add items
set.Add("berlin")
set.Add("istanbul") // nothing happens if you add duplicate item

// remove item
set.Remove("frankfurt")
set.Remove("frankfurt") // nothing happes if you remove a nonexisting item

// create a new copy
other := set.Copy() 

// remove all items
set.Clear()

// check for set emptiness
set.IsEmpty()

// check for a single item exist
if set.Has("istanbul") {
  ...
  ...
}

// number of items in the set
len := set.Size()

// return a list of items
items := set.List()

```

Set Operations


```go
a := goset.New("ankara", "berlin", "san francisco") // now with some values
b := goset.New("frankfurt", "berlin")               // now with some values

// creates a new set with the items in a and b combined.
c := a.Union(b) // [frankfurt, berlin, ankara, san francisco]

// contains items which is in both a and b
// [berlin]
c = a.Intersection(b) 

// contains items which are in a but not in b
// [ankara, san francisco]
c = a.Difference(b) 

// contains items which are in one of either, but not in both.
// [frankfurt, ankara, san francisco]
c = a.SymmetricDifference(b) 

```

```go
// like Union but saves the result back into a.
a.Merge(b)

// removes the set items which are in b from a and saves the result back into a.
a.Sepereate(b)

```


