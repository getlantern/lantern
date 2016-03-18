// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import "unicode/utf16"

// Based heavily on package unicode/utf16 from the Go standard library.

const (
	replacementChar = '\uFFFD'     // Unicode replacement character
	maxRune         = '\U0010FFFF' // Maximum valid Unicode code point.
)

const (
	// 0xd800-0xdc00 encodes the high 10 bits of a pair.
	// 0xdc00-0xe000 encodes the low 10 bits of a pair.
	// the value is those 20 bits plus 0x10000.
	surr1 = 0xd800
	surr2 = 0xdc00
	surr3 = 0xe000

	surrSelf = 0x10000
)

// UTF16Encode utf16 encodes s into chars. It returns the resulting
// length in units of uint16. It is assumed that the chars slice
// has enough room for the encoded string.
func UTF16Encode(s string, chars []uint16) int {
	n := 0
	for _, v := range s {
		switch {
		case v < 0, surr1 <= v && v < surr3, v > maxRune:
			v = replacementChar
			fallthrough
		case v < surrSelf:
			chars[n] = uint16(v)
			n += 1
		default:
			// surrogate pair, two uint16 values
			r1, r2 := utf16.EncodeRune(v)
			chars[n] = uint16(r1)
			chars[n+1] = uint16(r2)
			n += 2
		}
	}
	return n
}
