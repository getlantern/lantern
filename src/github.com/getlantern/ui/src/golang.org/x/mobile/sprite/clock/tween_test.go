// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package clock

import "testing"

func TestLinear(t *testing.T) {
	t0 := Time(0)
	t1 := Time(6 * 60)
	now := Time(3 * 60)

	if c := Linear(t0, t1, now); c != 0.5 {
		t.Errorf("c=%.2f, want 0.5", c)
	}
}

func TestCubicBezier(t *testing.T) {
	t0 := Time(0)
	t1 := Time(1e6)

	tests := []struct {
		x0, y0, x1, y1 float32
		x, y           float32
	}{
		{0.00, 0.1, 0.4, 1.00, 0.0, 0.00},
		{0.00, 0.1, 0.4, 1.00, 0.1, 0.26},
		{0.00, 0.1, 0.4, 1.00, 0.5, 0.79},
		{0.00, 0.1, 0.4, 1.00, 0.9, 0.99},
		{0.00, 0.1, 0.4, 1.00, 1.0, 1.00},
		{0.36, 0.2, 0.3, 0.85, 0.0, 0.0},
		{0.36, 0.2, 0.3, 0.85, 0.3059, 0.3952},
		{0.36, 0.2, 0.3, 0.85, 0.4493, 0.6408},
		{0.36, 0.2, 0.3, 0.85, 0.8116, 0.9410},
		{0.00, 0.0, 1.0, 1.00, 0.1, 0.1},
		{0.00, 0.0, 1.0, 1.00, 0.5, 0.5},
		{0.00, 0.0, 1.0, 1.00, 0.9, 0.9},
		{0.42, 0.0, 1.0, 1.00, 0.0, 0.0},
	}

	for _, test := range tests {
		cb := CubicBezier(test.x0, test.y0, test.x1, test.y1)
		now := t0 + Time(float32(t1-t0)*test.x)
		y := cb(t0, t1, now)

		const epsilon = 0.01
		diff := y - test.y
		if diff < -epsilon || +epsilon < diff {
			t.Errorf("CubicBezier(%.2f,%.2f,%.2f,%.2f): for x=%.2f got y=%.2f, want %.2f", test.x0, test.y0, test.x1, test.y1, test.x, y, test.y)
		}
	}
}
