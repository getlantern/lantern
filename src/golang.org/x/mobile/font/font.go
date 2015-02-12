// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin

package font

// Default returns the default system font.
// The font is encoded as a TTF.
func Default() []byte {
	b, err := buildDefault()
	if err != nil {
		panic(err)
	}
	return b
}

// Monospace returns the default system fixed-pitch font.
// The font is encoded as a TTF.
func Monospace() []byte {
	b, err := buildMonospace()
	if err != nil {
		panic(err)
	}
	return b
}
