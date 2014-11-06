// +build !go1.3

package stack

import (
	"runtime"
)

func getUintptrs() []uintptr {
	var s []uintptr
	select {
	case s = <-pcStackPool:
		s = s[:cap(s)]
	default:
		s = make([]uintptr, 1000)
	}
	return s
}

func putUintptrs(s []uintptr) {
	select {
	case pcStackPool <- s:
	default:
	}
}

var pcStackPool = make(chan []uintptr, runtime.GOMAXPROCS(0))
