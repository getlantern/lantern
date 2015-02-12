// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package debug provides GL-based debugging tools for apps.
package debug // import "golang.org/x/mobile/app/debug"

import (
	"fmt"
	"image"
	"image/draw"
	"log"
	"math"
	"sync"
	"time"

	"code.google.com/p/freetype-go/freetype"
	"golang.org/x/mobile/font"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl/glutil"
)

var lastDraw = time.Now()

var monofont = freetype.NewContext()

var fps struct {
	sync.Once
	*glutil.Image
}

// TODO(crawshaw): It looks like we need a gl.RegisterInit feature.
// TODO(crawshaw): The gldebug mode needs to complain loudly when GL functions
//                 are called before init, because often they fail silently.
func fpsInit() {
	b := font.Monospace()
	f, err := freetype.ParseFont(b)
	if err != nil {
		panic(err)
	}
	monofont.SetFont(f)
	monofont.SetSrc(image.Black)
	monofont.SetHinting(freetype.FullHinting)

	toPx := func(x geom.Pt) int { return int(math.Ceil(float64(geom.Pt(x).Px()))) }
	fps.Image = glutil.NewImage(toPx(50), toPx(12))
	monofont.SetDst(fps.Image.RGBA)
	monofont.SetClip(fps.Bounds())
	monofont.SetDPI(72 * float64(geom.PixelsPerPt))
	monofont.SetFontSize(12)
}

// DrawFPS draws the per second framerate in the bottom-left of the screen.
func DrawFPS() {
	fps.Do(fpsInit)

	now := time.Now()
	diff := now.Sub(lastDraw)
	str := fmt.Sprintf("%.0f FPS", float32(time.Second)/float32(diff))
	draw.Draw(fps.Image, fps.Image.Rect, image.White, image.Point{}, draw.Src)

	ftpt12 := freetype.Pt(0, int(12*geom.PixelsPerPt))
	if _, err := monofont.DrawString(str, ftpt12); err != nil {
		log.Printf("DrawFPS: %v", err)
		return
	}

	fps.Upload()
	fps.Draw(
		geom.Point{0, geom.Height - 12},
		geom.Point{50, geom.Height - 12},
		geom.Point{0, geom.Height},
		fps.Bounds(),
	)

	lastDraw = now
}
