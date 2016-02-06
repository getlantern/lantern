package balancer

import (
	"math/rand"
)

func Sticky(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		mi := dialers[i].metrics()
		mj := dialers[j].metrics()
		return (mi.consecSuccesses - mi.consecFailures) >
			(mj.consecSuccesses - mj.consecFailures)
	}}
}

func Fastest(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		mi := dialers[i].metrics()
		mj := dialers[j].metrics()
		return mi.avgConnTime < mj.avgConnTime
	}}
}

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

/*func Weighted(ptSuccessRate, ptSpeed int) Strategy {
	return func(dialers []*dialer) dialerHeap {
		return dialerHeap{dialers, func(i, j int) bool {
			pr := float64(ptSuccessRate)
			pt := float64(ptSpeed)
			m1 := dialers[i].metrics()
			m2 := dialers[j].metrics()
			r1 := float64(m1.consecSuccesses - m1.consecFailures)
			r2 := float64(m2.consecSuccesses - m2.consecFailures)
			t1 := float64(m1.avgConnTime)
			t2 := float64(m2.avgConnTime)

			w1 := (r2/r1)*pr + (t1/t2)*pt
			w2 := (r1/r2)*pr + (t2/t1)*pt
			log.Tracef("w1=%f, w2=%f", w1, w2)
			return w1 < w2
		}}
	}
}*/

func RoundRobin(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		return i < j
	}}
}

func Random(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		// we don't need good randomness, skip seeding
		if rand.Intn(2) == 0 {
			return false
		}
		return true
	}}
}

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
	// Push and Pop use pointer receivers because they modify the slice's length,
	// not just its contents.
	s.dialers = append(s.dialers, x.(*dialer))
}

func (s *dialerHeap) Pop() interface{} {
	old := s.dialers
	n := len(old)
	x := old[n-1]
	s.dialers = old[0 : n-1]
	return x
}
