package balancer

import (
	"container/heap"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestStickyStrategy(t *testing.T) {
	d1 := &dialer{consecSuccesses: 3, consecFailures: 0}
	d2 := &dialer{consecSuccesses: 4, consecFailures: 0}

	h := Sticky([]*dialer{d1, d2})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d2, "should select dialer with more successes")
}

func TestFastestStrategy(t *testing.T) {
	d1 := &dialer{emaDialTime: (100 * time.Millisecond).Nanoseconds()}
	d2 := &dialer{emaDialTime: (99 * time.Millisecond).Nanoseconds()}

	h := Fastest([]*dialer{d1, d2})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d2, "should select faster dialer")
}

func TestQualityFirstStrategy(t *testing.T) {
	d1 := &dialer{consecSuccesses: 3, consecFailures: 0, emaDialTime: (10 * time.Millisecond).Nanoseconds()}
	d2 := &dialer{consecSuccesses: 4, consecFailures: 0, emaDialTime: (100 * time.Millisecond).Nanoseconds()}
	d3 := &dialer{consecSuccesses: 0, consecFailures: 1, emaDialTime: (10 * time.Millisecond).Nanoseconds()}

	h := QualityFirst([]*dialer{d1, d2})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d1, "should select faster dialer when both has positive successes")

	h = QualityFirst([]*dialer{d2, d3})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d2, "should select more reliable dialer even if it's slower")
}

func TestWeightedStrategy(t *testing.T) {
	d1 := &dialer{consecSuccesses: 3, consecFailures: 0, emaDialTime: (100 * time.Millisecond).Nanoseconds()}
	d2 := &dialer{consecSuccesses: 4, consecFailures: 0, emaDialTime: (100 * time.Millisecond).Nanoseconds()}
	d3 := &dialer{consecSuccesses: 0, consecFailures: 1, emaDialTime: (10 * time.Millisecond).Nanoseconds()}
	d4 := &dialer{consecSuccesses: 4, consecFailures: 0, emaDialTime: (150 * time.Millisecond).Nanoseconds()}

	h := Weighted(9, 1)([]*dialer{d1, d2})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d2, "should select dialer with more successes")

	h = Weighted(9, 1)([]*dialer{d2, d3})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d2, "should select dialer with more successes")

	h = Weighted(9, 1)([]*dialer{d1, d4})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d4, "should select dialer with more successes")

	h = Weighted(5, 5)([]*dialer{d1, d4})
	heap.Init(&h)
	assert.Equal(t, heap.Pop(&h), d4, "should select dialer with more successes")
}
