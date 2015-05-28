// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin

package font

import (
	"testing"

	"code.google.com/p/freetype-go/freetype"
)

func TestLoadFonts(t *testing.T) {
	if _, err := freetype.ParseFont(Default()); err != nil {
		t.Fatalf("default font: %v", err)
	}
	if _, err := freetype.ParseFont(Monospace()); err != nil {
		t.Fatalf("monospace font: %v", err)
	}
}
