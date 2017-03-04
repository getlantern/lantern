package balancer

import "math/rand"

// Strategy determines the next dialer balancer will use given various
// metrics of each dialer.
type Strategy func(dialers []*dialer) dialerHeap

// Random strategy gives even chance to each dialer, act as a baseline to other
// strategies.
func Random(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers: dialers, lessFunc: func(i, j int) bool {
		// we don't need good randomness, skip seeding
		return rand.Intn(2) != 0
	}}
}

// Sticky strategy always pick the dialer with the biggest difference between
// consecutive successes and consecutive failures.
func Sticky(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers: dialers, lessFunc: func(i, j int) bool {
		q1 := dialers[i].ConsecSuccesses() - dialers[i].ConsecFailures()
		q2 := dialers[j].ConsecSuccesses() - dialers[j].ConsecFailures()
		return q1 > q2
	}}
}

// Fastest strategy always pick the dialer with lowest recent average connect time
func Fastest(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers: dialers, lessFunc: func(i, j int) bool {
		return dialers[i].EMADialTime() < dialers[j].EMADialTime()
	}}
}

// QualityFirst strategy behaves the same as Fastest strategy when both dialers
// are good recently, and falls back to Sticky strategy in other cases.
func QualityFirst(dialers []*dialer) dialerHeap {
	return dialerHeap{dialers: dialers, lessFunc: func(i, j int) bool {
		q1 := dialers[i].ConsecSuccesses() - dialers[i].ConsecFailures()
		q2 := dialers[j].ConsecSuccesses() - dialers[j].ConsecFailures()
		if q1 > 0 && q2 > 0 {
			return dialers[i].EMADialTime() < dialers[j].EMADialTime()
		}
		return q1 > q2
	}}
}

// TODO: still need to implement algorithm correctly.
// ptQuality: the percentage network quality contributes to total weight.
// the rest (100 - ptQuality) will be contributed by recent average connect time.
func Weighted(ptQuality int, ptSpeed int) Strategy {
	log.Error("Using the Weighted balancer strategy.  This strategy is incomplete and may not work as expected.")
	return func(dialers []*dialer) dialerHeap {
		pq := float64(ptQuality)
		pt := float64(ptSpeed)
		return dialerHeap{dialers: dialers, lessFunc: func(i, j int) bool {
			q1 := float64(dialers[i].ConsecSuccesses() - dialers[i].ConsecFailures())
			q2 := float64(dialers[j].ConsecSuccesses() - dialers[j].ConsecFailures())
			t1 := float64(dialers[i].EMADialTime())
			t2 := float64(dialers[i].EMADialTime())

			w1 := q2/(q1+q2)*pq + t1/(t1+t2)*pt
			w2 := q1/(q1+q2)*pq + t2/(t1+t2)*pt
			log.Tracef("q1=%f, q2=%f, t1=%f, t2=%f, w1=%f, w2=%f", q1, q2, t1, t2, w1, w2)
			return w1 < w2
		}}
	}
}
