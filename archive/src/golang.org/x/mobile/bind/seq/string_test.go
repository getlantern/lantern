// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import (
	"testing"
	"unicode/utf16"
)

var strData = []string{
	"abcxyz09{}",
	"Hello, 世界",
	string([]rune{0xffff, 0x10000, 0x10001, 0x12345, 0x10ffff}),
}

func TestString(t *testing.T) {
	for _, test := range strData {
		chars := make([]uint16, 4*len(test))
		nchars := UTF16Encode(test, chars)
		chars = chars[:nchars]
		got := string(utf16.Decode(chars))
		if got != test {
			t.Errorf("UTF16: got %q, want %q", got, test)
		}
	}
}
