// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import "testing"

var utf16Tests = []string{
	"abcxyz09{}",
	"Hello, 世界",
	string([]rune{0xffff, 0x10000, 0x10001, 0x12345, 0x10ffff}),
}

func TestUTF16(t *testing.T) {
	for _, test := range utf16Tests {
		buf := new(Buffer)
		buf.WriteUTF16(test)
		buf.Offset = 0
		got := buf.ReadUTF16()
		if got != test {
			t.Errorf("got %q, want %q", got, test)
		}
	}
}

func TestSequential(t *testing.T) {
	buf := new(Buffer)
	for _, test := range utf16Tests {
		buf.WriteUTF16(test)
	}
	buf.Offset = 0
	for i, test := range utf16Tests {
		got := buf.ReadUTF16()
		if got != test {
			t.Errorf("%d: got %q, want %q", i, got, test)
		}
	}
}
