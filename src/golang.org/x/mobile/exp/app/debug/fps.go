// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package debug provides GL-based debugging tools for apps.
package debug // import "golang.org/x/mobile/exp/app/debug"

import (
	"image"
	"image/color"
	"image/draw"
	"sync"
	"time"

	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/exp/gl/glutil"
	"golang.org/x/mobile/geom"
)

var lastDraw = time.Now()

var fps struct {
	mu sync.Mutex
	c  config.Event
	m  *glutil.Image
}

// DrawFPS draws the per second framerate in the bottom-left of the screen.
func DrawFPS(c config.Event) {
	const imgW, imgH = 7*(fontWidth+1) + 1, fontHeight + 2

	fps.mu.Lock()
	if fps.c != c || fps.m == nil {
		fps.c = c
		fps.m = glutil.NewImage(imgW, imgH)
	}
	fps.mu.Unlock()

	display := [7]byte{
		4: 'F',
		5: 'P',
		6: 'S',
	}
	now := time.Now()
	f := 0
	if dur := now.Sub(lastDraw); dur > 0 {
		f = int(time.Second / dur)
	}
	display[2] = '0' + byte((f/1e0)%10)
	display[1] = '0' + byte((f/1e1)%10)
	display[0] = '0' + byte((f/1e2)%10)
	draw.Draw(fps.m.RGBA, fps.m.RGBA.Bounds(), image.White, image.Point{}, draw.Src)
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
				fps.m.RGBA.SetRGBA((fontWidth+1)*i+x+1, y+1, color.RGBA{A: 0xff})
			}
		}
	}

	fps.m.Upload()
	fps.m.Draw(
		c,
		geom.Point{0, c.Height - imgH},
		geom.Point{imgW, c.Height - imgH},
		geom.Point{0, c.Height},
		fps.m.Bounds(),
	)

	lastDraw = now
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
