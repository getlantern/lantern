// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package clock

// Standard tween functions.
//
// Easing means a slowing near the timing boundary, as defined by
// a cubic bezier curve. Exact parameters match the CSS properties.
var (
	EaseIn    = CubicBezier(0.42, 0, 1, 1)
	EaseOut   = CubicBezier(0, 0, 0.58, 1)
	EaseInOut = CubicBezier(0.42, 0, 0.58, 1)
)

// Linear computes the fraction [0,1] that t lies between [t0,t1].
func Linear(t0, t1, t Time) float32 {
	if t >= t1 {
		return 1
	}
	if t <= t0 {
		return 0
	}
	return float32(t-t0) / float32(t1-t0)
}

// CubicBezier generates a tween function determined by a Cubic Bézier curve.
//
// The parameters are cubic control parameters. The curve starts at (0,0)
// going toward (x0,y0), and arrives at (1,1) coming from (x1,y1).
func CubicBezier(x0, y0, x1, y1 float32) func(t0, t1, t Time) float32 {
	return func(start, end, now Time) float32 {
		// A Cubic-Bezier curve restricted to starting at (0,0) and
		// ending at (1,1) is defined as
		//
		// 	B(t) = 3*(1-t)^2*t*P0 + 3*(1-t)*t^2*P1 + t^3
		//
		// with derivative
		//
		//	B'(t) = 3*(1-t)^2*P0 + 6*(1-t)*t*(P1-P0) + 3*t^2*(1-P1)
		//
		// Given a value x ∈ [0,1], we solve for t using Newton's
		// method and solve for y using t.

		x := Linear(start, end, now)

		// Solve for t using x.
		t := x
		for i := 0; i < 5; i++ {
			t2 := t * t
			t3 := t2 * t
			d := 1 - t
			d2 := d * d

			nx := 3*d2*t*x0 + 3*d*t2*x1 + t3
			dxdt := 3*d2*x0 + 6*d*t*(x1-x0) + 3*t2*(1-x1)
			if dxdt == 0 {
				break
			}

			t -= (nx - x) / dxdt
			if t <= 0 || t >= 1 {
				break
			}
		}
		if t < 0 {
			t = 0
		}
		if t > 1 {
			t = 1
		}

		// Solve for y using t.
		t2 := t * t
		t3 := t2 * t
		d := 1 - t
		d2 := d * d
		y := 3*d2*t*y0 + 3*d*t2*y1 + t3

		return y
	}
}
