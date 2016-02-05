package balancer

import (
	//"container/heap"
	"math/rand"
)

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

type HeapCreater func(dialers []*dialer) dialerHeap

func Sticky(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers, func(i, j int) bool {
		mi := dialers[i].metrics()
		mj := dialers[j].metrics()
		return (mi.consecSuccesses - mi.consecFailures) <
			(mj.consecSuccesses - mj.consecFailures)
	}}
}

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
