// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import "testing"

var strData = []string{
	"abcxyz09{}",
	"Hello, 世界",
	string([]rune{0xffff, 0x10000, 0x10001, 0x12345, 0x10ffff}),
}

var stringEncoder = map[string]struct {
	write func(*Buffer, string)
	read  func(*Buffer) string
}{
	"UTF16": {write: (*Buffer).WriteUTF16, read: (*Buffer).ReadUTF16},
	"UTF8":  {write: (*Buffer).WriteUTF8, read: (*Buffer).ReadUTF8},
}

func TestString(t *testing.T) {
	for encoding, f := range stringEncoder {
		for _, test := range strData {
			buf := new(Buffer)
			f.write(buf, test)
			buf.Offset = 0
			got := f.read(buf)
			if got != test {
				t.Errorf("%s: got %q, want %q", encoding, got, test)
			}
		}
	}
}

func TestSequential(t *testing.T) {
	for encoding, f := range stringEncoder {
		buf := new(Buffer)
		for _, test := range strData {
			f.write(buf, test)
		}
		buf.Offset = 0
		for i, test := range strData {
			got := f.read(buf)
			if got != test {
				t.Errorf("%s: %d: got %q, want %q", encoding, i, got, test)
			}
		}
	}
}
