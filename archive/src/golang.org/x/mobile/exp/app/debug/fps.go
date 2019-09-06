// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux windows

// Package debug provides GL-based debugging tools for apps.
package debug // import "golang.org/x/mobile/exp/app/debug"

import (
	"image"
	"image/color"
	"image/draw"
	"time"

	"golang.org/x/mobile/event/size"
	"golang.org/x/mobile/exp/gl/glutil"
	"golang.org/x/mobile/geom"
)

// FPS draws a count of the frames rendered per second.
type FPS struct {
	sz       size.Event
	images   *glutil.Images
	m        *glutil.Image
	lastDraw time.Time
	// TODO: store *gl.Context
}

// NewFPS creates an FPS tied to the current GL context.
func NewFPS(images *glutil.Images) *FPS {
	return &FPS{
		lastDraw: time.Now(),
		images:   images,
	}
}

// Draw draws the per second framerate in the bottom-left of the screen.
func (p *FPS) Draw(sz size.Event) {
	const imgW, imgH = 7*(fontWidth+1) + 1, fontHeight + 2

	if sz.WidthPx == 0 && sz.HeightPx == 0 {
		return
	}
	if p.sz != sz {
		p.sz = sz
		if p.m != nil {
			p.m.Release()
		}
		p.m = p.images.NewImage(imgW, imgH)
	}

	display := [7]byte{
		4: 'F',
		5: 'P',
		6: 'S',
	}
	now := time.Now()
	f := 0
	if dur := now.Sub(p.lastDraw); dur > 0 {
		f = int(time.Second / dur)
	}
	display[2] = '0' + byte((f/1e0)%10)
	display[1] = '0' + byte((f/1e1)%10)
	display[0] = '0' + byte((f/1e2)%10)
	draw.Draw(p.m.RGBA, p.m.RGBA.Bounds(), image.White, image.Point{}, draw.Src)
	for i, c := range display {
		glyph := glyphs[c]
		if len(glyph) != fontWidth*fontHeight {
			continue
		}
		for y := 0; y < fontHeight; y++ {
			for x := 0; x < fontWidth; x++ {
				if glyph[fontWidth*y+x] == ' ' {
					continue
				}
				p.m.RGBA.SetRGBA((fontWidth+1)*i+x+1, y+1, color.RGBA{A: 0xff})
			}
		}
	}

	p.m.Upload()
	p.m.Draw(
		sz,
		geom.Point{0, sz.HeightPt - imgH},
		geom.Point{imgW, sz.HeightPt - imgH},
		geom.Point{0, sz.HeightPt},
		p.m.RGBA.Bounds(),
	)

	p.lastDraw = now
}

func (f *FPS) Release() {
	if f.m != nil {
		f.m.Release()
		f.m = nil
		f.images = nil
	}
}

const (
	fontWidth  = 5
	fontHeight = 7
)

// glyphs comes from the 6x10 fixed font from the plan9port:
// https://github.com/9fans/plan9port/tree/master/font/fixed
//
// 6x10 becomes 5x7 because each glyph has a 1-pixel margin plus space for
// descenders.
//
// Its README file says that those fonts were converted from XFree86, and are
// in the public domain.
var glyphs = [256]string{
	'0': "" +
		"  X  " +
		" X X " +
		"X   X" +
		"X   X" +
		"X   X" +
		" X X " +
		"  X  ",
	'1': "" +
		"  X  " +
		" XX  " +
		"X X  " +
		"  X  " +
		"  X  " +
		"  X  " +
		"XXXXX",
	'2': "" +
		" XXX " +
		"X   X" +
		"    X" +
		"  XX " +
		" X   " +
		"X    " +
		"XXXXX",
	'3': "" +
		"XXXXX" +
		"    X" +
		"   X " +
		"  XX " +
		"    X" +
		"X   X" +
		" XXX ",
	'4': "" +
		"   X " +
		"  XX " +
		" X X " +
		"X  X " +
		"XXXXX" +
		"   X " +
		"   X ",
	'5': "" +
		"XXXXX" +
		"X    " +
		"X XX " +
		"XX  X" +
		"    X" +
		"X   X" +
		" XXX ",
	'6': "" +
		"  XX " +
		" X   " +
		"X    " +
		"X XX " +
		"XX  X" +
		"X   X" +
		" XXX ",
	'7': "" +
		"XXXXX" +
		"    X" +
		"   X " +
		"   X " +
		"  X  " +
		" X   " +
		" X   ",
	'8': "" +
		" XXX " +
		"X   X" +
		"X   X" +
		" XXX " +
		"X   X" +
		"X   X" +
		" XXX ",
	'9': "" +
		" XXX " +
		"X   X" +
		"X  XX" +
		" XX X" +
		"    X" +
		"   X " +
		" XX  ",
	'F': "" +
		"XXXXX" +
		"X    " +
		"X    " +
		"XXXX " +
		"X    " +
		"X    " +
		"X    ",
	'P': "" +
		"XXXX " +
		"X   X" +
		"X   X" +
		"XXXX " +
		"X    " +
		"X    " +
		"X    ",
	'S': "" +
		" XXX " +
		"X   X" +
		"X    " +
		" XXX " +
		"    X" +
		"X   X" +
		" XXX ",
}
