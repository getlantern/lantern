package balancer

import (
	"bytes"
	"fmt"
	"regexp"
	"testing"
	"time"

	"github.com/getlantern/golog"
)

func BenchmarkRandom(b *testing.B) {
	benchmarkWithRandomlyFail(b, Random)
	benchmarkWithRandomlyFailWithVariedDelay(b, Random)
}

func BenchmarkSticky(b *testing.B) {
	benchmarkWithRandomlyFail(b, Sticky)
	benchmarkWithRandomlyFailWithVariedDelay(b, Sticky)
}

func BenchmarkFastest(b *testing.B) {
	benchmarkWithRandomlyFail(b, Fastest)
	benchmarkWithRandomlyFailWithVariedDelay(b, Fastest)
}

func BenchmarkQualityFirst(b *testing.B) {
	benchmarkWithRandomlyFail(b, QualityFirst)
	benchmarkWithRandomlyFailWithVariedDelay(b, QualityFirst)
}

func BenchmarkWeighted(b *testing.B) {
	benchmarkWithRandomlyFail(b, Weighted(9, 1))
	benchmarkWithRandomlyFailWithVariedDelay(b, Weighted(9, 1))
}

func benchmarkWithRandomlyFail(b *testing.B, s Strategy) {
	d1 := RandomlyFail(1)
	d2 := RandomlyFail(10)
	d3 := RandomlyFail(99)
	bal := New(s, d1, d2, d3)
	runBenchmark(b, bal)
}

func benchmarkWithRandomlyFailWithVariedDelay(b *testing.B, s Strategy) {
	d1 := RandomlyFailWithVariedDelay(1, 10*time.Nanosecond, 8*time.Nanosecond)
	d2 := RandomlyFailWithVariedDelay(10, 10*time.Nanosecond, 8*time.Nanosecond)
	d3 := RandomlyFailWithVariedDelay(99, 10*time.Nanosecond, 8*time.Nanosecond)
	bal := New(s, d1, d2, d3)
	runBenchmark(b, bal)
}

func runBenchmark(b *testing.B, bal *Balancer) {
	var errBuf bytes.Buffer
	var outBuf bytes.Buffer
	golog.SetOutputs(&errBuf, &outBuf)
	buf := make([]byte, 100)
	for i := 0; i < b.N; i++ { //use b.N for looping
		var nr, nw int
		c, err := bal.Dial("xxx", "yyy")
		if err != nil {
			continue
		}
		nw, err = c.Write([]byte(fmt.Sprintf("iteration %d", i)))
		if err != nil {
			goto Skip
		}
		nr, err = c.Read(buf)
		if err != nil {
			goto Skip
		}
		if nr != nw {
			b.Fatal("not equal!")
		}
	Skip:
		// Use goto because defer has significant performance impact
		_ = c.Close()
	}
	b.StopTimer()
	defer b.StartTimer()
	if b.N < 1000 {
		return
	}
	var totalFailures, totalSuccesses int
	var line string
	for _, d := range bal.dialers.dialers {
		re, err := regexp.Compile(d.Label)
		if err != nil {
			b.Fatalf("Regexp error: %s", err)
		}
		failures := len(re.FindAll(errBuf.Bytes(), -1))
		successes := len(re.FindAll(outBuf.Bytes(), -1))
		line = line + fmt.Sprintf("%s: %d/%d, ", d.Label, failures, failures+successes)
		totalFailures = totalFailures + failures
		totalSuccesses = totalSuccesses + successes
	}
	b.Logf("%s fail/total = %d/%d (%.1f%%) in %d runs", line, totalFailures, totalFailures+totalSuccesses, float64(totalFailures)*100/float64(totalFailures+totalSuccesses), b.N)
}
