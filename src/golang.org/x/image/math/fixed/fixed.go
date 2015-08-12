// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package fixed implements fixed-point integer types.
package fixed // import "golang.org/x/image/math/fixed"

import (
	"fmt"
)

// TODO: implement fmt.Formatter for %f and %g.

// Int26_6 is a signed 26.6 fixed-point number.
//
// The integer part ranges from -33554432 to 33554431, inclusive. The
// fractional part has 6 bits of precision.
//
// For example, the number one-and-a-quarter is Int26_6(1<<6 + 1<<4).
type Int26_6 int32

// String returns a human-readable representation of a 26.6 fixed-point number.
//
// For example, the number one-and-a-quarter becomes "1:16".
func (x Int26_6) String() string {
	const shift, mask = 6, 1<<6 - 1
	if x >= 0 {
		return fmt.Sprintf("%d:%02d", int32(x>>shift), int32(x&mask))
	}
	x = -x
	if x >= 0 {
		return fmt.Sprintf("-%d:%02d", int32(x>>shift), int32(x&mask))
	}
	return "-33554432:00" // The minimum value is -(1<<25).
}

// Int52_12 is a signed 52.12 fixed-point number.
//
// The integer part ranges from -2251799813685248 to 2251799813685247,
// inclusive. The fractional part has 12 bits of precision.
//
// For example, the number one-and-a-quarter is Int52_12(1<<12 + 1<<10).
type Int52_12 int64

// String returns a human-readable representation of a 52.12 fixed-point
// number.
//
// For example, the number one-and-a-quarter becomes "1:1024".
func (x Int52_12) String() string {
	const shift, mask = 12, 1<<12 - 1
	if x >= 0 {
		return fmt.Sprintf("%d:%04d", int64(x>>shift), int64(x&mask))
	}
	x = -x
	if x >= 0 {
		return fmt.Sprintf("-%d:%04d", int64(x>>shift), int64(x&mask))
	}
	return "-2251799813685248:0000" // The minimum value is -(1<<51).
}

// Point26_6 is a 26.6 fixed-point coordinate pair.
type Point26_6 struct {
	X, Y Int26_6
}

// Point52_12 is a 52.12 fixed-point coordinate pair.
type Point52_12 struct {
	X, Y Int52_12
}
