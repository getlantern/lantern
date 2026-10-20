//go:build ignore

// Standalone probe of the 32-bit runtime shared by Linux and Android.
package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

func main() {
	runtime.GOMAXPROCS(2)
	var workers sync.WaitGroup
	for range 8 {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for range 10 {
				time.Sleep(time.Millisecond)
				runtime.Gosched()
			}
		}()
	}
	workers.Wait()
	fmt.Printf("runtime-startup-ok %s %s/%s\n", runtime.Version(), runtime.GOOS, runtime.GOARCH)
}
