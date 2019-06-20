// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin

package font

import (
	"bytes"
	"fmt"
	"testing"
)

func looksLikeATTF(b []byte) error {
	if len(b) < 256 {
		return fmt.Errorf("not a TTF: not enough data")
	}
	b = b[:256]

	// Look for the 4-byte magic header. See
	// http://www.microsoft.com/typography/otspec/otff.htm
	switch string(b[:4]) {
	case "\x00\x01\x00\x00", "ttcf":
		// No-op.
	default:
		return fmt.Errorf("not a TTF: missing magic header")
	}

	// Look for a glyf table.
	if i := bytes.Index(b, []byte("glyf")); i < 0 {
		return fmt.Errorf(`not a TTF: missing "glyf" table`)
	} else if i%0x10 != 0x0c {
		return fmt.Errorf(`not a TTF: invalid "glyf" offset 0x%02x`, i)
	}
	return nil
}

func TestLoadFonts(t *testing.T) {
	if err := looksLikeATTF(Default()); err != nil {
		t.Errorf("default font: %v", err)
	}
	if err := looksLikeATTF(Monospace()); err != nil {
		t.Errorf("monospace font: %v", err)
	}
}
