package balancer

import (
	"math/rand"
)

// Random strategy gives even chance to each dialer, act as a baseline to other
// strategies.
func Random(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		// we don't need good randomness, skip seeding
		if rand.Intn(2) == 0 {
			return false
		}
		return true
	}}
}

// Sticky strategy always pick the dialer with largest consecutive success
// count or the smallest consecutive failure count
func Sticky(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		mi := dialers[i].metrics()
		mj := dialers[j].metrics()
		return (mi.consecSuccesses - mi.consecFailures) >
			(mj.consecSuccesses - mj.consecFailures)
	}}
}

// Fastest strategy always pick the dialer with lowest recent average connect time
func Fastest(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		mi := dialers[i].metrics()
		mj := dialers[j].metrics()
		return mi.avgConnTime < mj.avgConnTime
	}}
}

// QualityFirst strategy behaves the same as Fastest strategy when both dialers
// are good recently, and falls back to Sticky strategy in other cases.
func QualityFirst(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		mi := dialers[i].metrics()
		mj := dialers[j].metrics()
		r1 := mi.consecSuccesses - mi.consecFailures
		r2 := mj.consecSuccesses - mj.consecFailures
		if r1 > 0 && r2 > 0 {
			return mi.avgConnTime < mj.avgConnTime
		}
		return r1 > r2
	}}
}

// TODO: still need to implement algorithm correctly.
// ptQuality: the percentage network quality contributes to total weight.
// the rest (100 - ptQuality) will be contributed by recent average connect time.
func Weighted(ptQuality int) Strategy {
	return func(dialers []*dialer) dialerHeap {
		pq := float64(ptQuality)
		pt := float64(100 - ptQuality)
		return dialerHeap{dialers, func(i, j int) bool {
			m1 := dialers[i].metrics()
			m2 := dialers[j].metrics()
			r1 := float64(m1.consecSuccesses - m1.consecFailures)
			r2 := float64(m2.consecSuccesses - m2.consecFailures)
			t1 := float64(m1.avgConnTime)
			t2 := float64(m2.avgConnTime)

			w1 := (r2/r1)*pq + (t1/t2)*pt
			w2 := (r1/r2)*pq + (t2/t1)*pt
			log.Tracef("w1=%f, w2=%f", w1, w2)
			return w1 < w2
		}}
	}
}

// Strategy determines the next dialer balancer will use give various
// statistics of each dialer.
type Strategy func(dialers []*dialer) dialerHeap

type dialerHeap struct {
	dialers  []*dialer
	LessFunc func(i, j int) bool
}

func (s dialerHeap) Len() int { return len(s.dialers) }

func (s dialerHeap) Swap(i, j int) {
	s.dialers[i], s.dialers[j] = s.dialers[j], s.dialers[i]
}

func (s dialerHeap) Less(i, j int) bool {
	return s.LessFunc(i, j)
}

func (s *dialerHeap) Push(x interface{}) {
	s.dialers = append(s.dialers, x.(*dialer))
}

func (s *dialerHeap) Pop() interface{} {
	old := s.dialers
	n := len(old)
	x := old[n-1]
	s.dialers = old[0 : n-1]
	return x
}
