# GoSet

GoSet is a basic and simple *thread safe* SET data structure implementation in
Go. Because it's thread safe, you can use it concurrently with your goroutines.

For more info look at godoc: [GoSet godoc](http://godoc.org/github.com/fatih/goset)

## Install

```bash
go get github.com/fatih/goset
```

## Example

```go
package main

import (
	"fmt"
	"github.com/fatih/goset"
)

func main() {
	// initialize a new set
	set := goset.New()

	// add items
	set.Add("istanbul")
	set.Add("istanbul") // duplicate item
	set.Add("sf")
	set.Add("frankfurt")

	// ... or some integers
	set.Add(8)
	set.Add(13)
	set.Add(13) // again a duplicate item
	set.Add(21)

	// show the total size and content of the set
	fmt.Printf("total # of items: %d\n", set.Len())
	fmt.Printf("set items: %v\n", set.List())

	// remove all items from the set
	set.Clear()

	// check if the set is empty
	if set.IsEmpty() {
		fmt.Printf("we have 0 items\n")
	}

	// check if the set contains the item
	set.Add("gopher")
	if set.Has("gopher") {
		fmt.Println("gopher does exist")
	}

	// remove some items
	set.Remove("gopher")
	set.Remove("coffee") // does not exist
	fmt.Println("list of all items:", set.List())
}
```
