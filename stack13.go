// +build go1.3

package stack

import (
	"sync"
)

func getUintptrs() []uintptr {
	s := pcStackPool.Get().([]uintptr)
	s = s[:cap(s)]
	return s
}

func putUintptrs(s []uintptr) {
	pcStackPool.Put(s)
}

var pcStackPool = sync.Pool{
	New: func() interface{} { return make([]uintptr, 1000) },
}
