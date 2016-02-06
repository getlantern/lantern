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
	benchmarkWithRandomlyFailWithDelay(b, Random)
}

func BenchmarkSticky(b *testing.B) {
	benchmarkWithRandomlyFail(b, Sticky)
	benchmarkWithRandomlyFailWithDelay(b, Sticky)
}

func BenchmarkFastest(b *testing.B) {
	benchmarkWithRandomlyFail(b, Fastest)
	benchmarkWithRandomlyFailWithDelay(b, Fastest)
}

func BenchmarkQualityFirst(b *testing.B) {
	benchmarkWithRandomlyFail(b, QualityFirst)
	benchmarkWithRandomlyFailWithDelay(b, QualityFirst)
}

func BenchmarkWeighted(b *testing.B) {
	benchmarkWithRandomlyFail(b, Weighted(90))
	benchmarkWithRandomlyFailWithDelay(b, Weighted(90))
}

func benchmarkWithRandomlyFail(b *testing.B, s Strategy) {
	d1 := RandomlyFail(1)
	d2 := RandomlyFail(10)
	d3 := RandomlyFail(50)
	bal := New(s, d1, d2, d3)
	runBenchmark(b, bal)
}

func benchmarkWithRandomlyFailWithDelay(b *testing.B, s Strategy) {
	d1 := RandomlyFailWithDelay(1, 10*time.Millisecond, 8*time.Millisecond)
	d2 := RandomlyFailWithDelay(10, 10*time.Millisecond, 8*time.Millisecond)
	d3 := RandomlyFailWithDelay(50, 10*time.Millisecond, 8*time.Millisecond)
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
		c.Close()
	}
	if b.N < 1000 {
		return
	}
	var total int
	for _, d := range bal.dialers.dialers {
		re, err := regexp.Compile(d.Label)
		if err != nil {
			b.Fatalf("Regexp error: %s", err)
		}
		matches := re.FindAll(errBuf.Bytes(), -1)
		b.Logf("%s: %d", d.Label, len(matches))
		total = total + len(matches)
	}
	b.Logf("- Failed dial attempts: %d out of %d", total, b.N)
}
