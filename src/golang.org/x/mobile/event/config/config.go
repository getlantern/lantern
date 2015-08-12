// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package config defines an event for the dimensions and physical resolution
// of the app's window.
//
// See the golang.org/x/mobile/app package for details on the event model.
package config // import "golang.org/x/mobile/event/config"

import (
	"image"

	"golang.org/x/mobile/geom"
)

// Event holds the dimensions and physical resolution of the app's window.
type Event struct {
	// WidthPx and HeightPx are the window's dimensions in pixels.
	WidthPx, HeightPx int

	// WidthPt and HeightPt are the window's dimensions in points (1/72 of an
	// inch).
	WidthPt, HeightPt geom.Pt

	// PixelsPerPt is the window's physical resolution. It is the number of
	// pixels in a single geom.Pt, from the golang.org/x/mobile/geom package.
	//
	// There are a wide variety of pixel densities in existing phones and
	// tablets, so apps should be written to expect various non-integer
	// PixelsPerPt values. In general, work in geom.Pt.
	PixelsPerPt float32
}

// Bounds returns the window's bounds in pixels, at the time this configuration
// event was sent.
//
// The top-left pixel is always (0, 0). The bottom-right pixel is given by the
// width and height.
func (e *Event) Bounds() image.Rectangle {
	return image.Rectangle{Max: image.Point{e.WidthPx, e.HeightPx}}
}
