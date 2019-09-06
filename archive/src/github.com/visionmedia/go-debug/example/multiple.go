package main

import . "github.com/visionmedia/go-debug"
import "time"

var a = Debug("multiple:a")
var b = Debug("multiple:b")
var c = Debug("multiple:c")

func work(debug DebugFunction, delay time.Duration) {
	for {
		debug("doing stuff")
		time.Sleep(delay)
	}
}

func main() {
	q := make(chan bool)

	go work(a, 1000*time.Millisecond)
	go work(b, 250*time.Millisecond)
	go work(c, 100*time.Millisecond)

	<-q
}
