// Package grtrack provides a utility that helps check for goroutine leaks.
package grtrack

import (
	"bytes"
	"regexp"
	"runtime/pprof"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

var (
	goroutineNumber = regexp.MustCompile(`goroutine ([0-9]+)`)
)

// Object that can be used to check whether goroutines have leaked at any point
// in time.
type Checker interface {
	// Check immediately checks whether there's been a leak
	Check(t *testing.T)

	// CheckAfter waits wait and then checks
	CheckAfter(t *testing.T, wait time.Duration)
}

type checker struct {
	check func(t *testing.T)
}

func Start() Checker {
	var buf bytes.Buffer
	_ = pprof.Lookup("goroutine").WriteTo(&buf, 2)
	before := buf.String()

	check := func(t *testing.T) {
		var buf bytes.Buffer
		_ = pprof.Lookup("goroutine").WriteTo(&buf, 2)
		after := buf.String()

		beforeGoroutines := make(map[string]bool)
		beforeMatches := goroutineNumber.FindAllStringSubmatch(before, -1)
		for _, match := range beforeMatches {
			beforeGoroutines[match[1]] = true
		}

		afterMatches := goroutineNumber.FindAllStringSubmatchIndex(after, -1)
		for i := 0; i < len(afterMatches); i++ {
			idx := afterMatches[i][0]
			nextIdx := len(after)
			last := i == len(afterMatches)-1
			if !last {
				nextIdx = afterMatches[i+1][0]
			}
			matches := goroutineNumber.FindAllStringSubmatch(after[idx:], 1)
			num := matches[0][1]
			_, exists := beforeGoroutines[num]
			if !exists {
				delta := after[idx:nextIdx]
				if !strings.Contains(delta, "net/http/server.go") {
					assert.Fail(t, "Leaked Goroutine", delta)
				}
			}
		}
	}

	return &checker{check}
}

func (c *checker) Check(t *testing.T) {
	c.check(t)
}

func (c *checker) CheckAfter(t *testing.T, wait time.Duration) {
	time.Sleep(wait)
	c.check(t)
}
