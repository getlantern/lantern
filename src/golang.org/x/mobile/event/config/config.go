// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package config defines an event for the dimensions and physical resolution
// of the app's window.
//
// See the golang.org/x/mobile/app package for details on the event model.
package config // import "golang.org/x/mobile/event/config"

import (
	"golang.org/x/mobile/geom"
)

// Event holds the dimensions and physical resolution of the app's window.
type Event struct {
	// Width and Height are the window's dimensions.
	Width, Height geom.Pt

	// PixelsPerPt is the window's physical resolution. It is the number of
	// pixels in a single geom.Pt, from the golang.org/x/mobile/geom package.
	//
	// There are a wide variety of pixel densities in existing phones and
	// tablets, so apps should be written to expect various non-integer
	// PixelsPerPt values. In general, work in geom.Pt.
	PixelsPerPt float32
}
