package draw

// Benchmarks. Some run as regular tests.

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

var (
	testOnce    sync.Once
	testDisplay *Display
)

func testInit() {
	var err error
	testDisplay, err = Init(nil, "", "drawtest", "")
	if err != nil {
		panic(err)
	}
}

const aHundredChars = "abcdefghijklmnopqrstuvwxyabcdefghijklmnopqrstuvwxyabcdefghijklmnopqrstuvwxyabcdefghijklmnopqrstuvwxy"

func TestBenchmarkString(t *testing.T) {
	testOnce.Do(testInit)
	im := testDisplay.Image
	start := time.Now()
	var nchars time.Duration
	for i := 0; i < 1e4; i++ {
		im.String(im.R.Min, testDisplay.Black, im.R.Min, testDisplay.DefaultFont, aHundredChars)
		nchars += 100
	}
	testDisplay.Flush()
	end := time.Now()
	fmt.Println("time for one char:", end.Sub(start)/nchars)
}
