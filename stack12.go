// +build !go1.3

package stack

import (
	"runtime"
)

func getUintptrs() []uintptr {
	select {
	case s := <-pcStackPool:
		return s[:cap(s)]
	default:
		return make([]uintptr, 1000)
	}
}

func putUintptrs(s []uintptr) {
	select {
	case pcStackPool <- s:
	default:
	}
}

var pcStackPool = make(chan []uintptr, runtime.GOMAXPROCS(n))
