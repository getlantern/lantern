// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package portable

import (
	"image"
	"image/color"
	"math"
)

func bilinear(src image.Image, x, y float32) color.Color {
	switch src := src.(type) {
	case *image.RGBA:
		return bilinearRGBA(src, x, y)
	case *image.Alpha:
		return bilinearAlpha(src, x, y)
	case *image.Uniform:
		return src.C
	default:
		return bilinearGeneral(src, x, y)
	}
}

func bilinearGeneral(src image.Image, x, y float32) color.RGBA64 {
	p := findLinearSrc(src.Bounds(), x, y)

	r00, g00, b00, a00 := src.At(p.low.X, p.low.Y).RGBA()
	r01, g01, b01, a01 := src.At(p.high.X, p.low.Y).RGBA()
	r10, g10, b10, a10 := src.At(p.low.X, p.high.Y).RGBA()
	r11, g11, b11, a11 := src.At(p.high.X, p.high.Y).RGBA()

	fr := float32(r00) * p.frac00
	fg := float32(g00) * p.frac00
	fb := float32(b00) * p.frac00
	fa := float32(a00) * p.frac00

	fr += float32(r01) * p.frac01
	fg += float32(g01) * p.frac01
	fb += float32(b01) * p.frac01
	fa += float32(a01) * p.frac01

	fr += float32(r10) * p.frac10
	fg += float32(g10) * p.frac10
	fb += float32(b10) * p.frac10
	fa += float32(a10) * p.frac10

	fr += float32(r11) * p.frac11
	fg += float32(g11) * p.frac11
	fb += float32(b11) * p.frac11
	fa += float32(a11) * p.frac11

	return color.RGBA64{
		R: uint16(fr + 0.5),
		G: uint16(fg + 0.5),
		B: uint16(fb + 0.5),
		A: uint16(fa + 0.5),
	}
}

func bilinearRGBA(src *image.RGBA, x, y float32) color.RGBA {
	p := findLinearSrc(src.Bounds(), x, y)

	// Slice offsets for the surrounding pixels.
	off00 := src.PixOffset(p.low.X, p.low.Y)
	off01 := src.PixOffset(p.high.X, p.low.Y)
	off10 := src.PixOffset(p.low.X, p.high.Y)
	off11 := src.PixOffset(p.high.X, p.high.Y)

	fr := float32(src.Pix[off00+0]) * p.frac00
	fg := float32(src.Pix[off00+1]) * p.frac00
	fb := float32(src.Pix[off00+2]) * p.frac00
	fa := float32(src.Pix[off00+3]) * p.frac00

	fr += float32(src.Pix[off01+0]) * p.frac01
	fg += float32(src.Pix[off01+1]) * p.frac01
	fb += float32(src.Pix[off01+2]) * p.frac01
	fa += float32(src.Pix[off01+3]) * p.frac01

	fr += float32(src.Pix[off10+0]) * p.frac10
	fg += float32(src.Pix[off10+1]) * p.frac10
	fb += float32(src.Pix[off10+2]) * p.frac10
	fa += float32(src.Pix[off10+3]) * p.frac10

	fr += float32(src.Pix[off11+0]) * p.frac11
	fg += float32(src.Pix[off11+1]) * p.frac11
	fb += float32(src.Pix[off11+2]) * p.frac11
	fa += float32(src.Pix[off11+3]) * p.frac11

	return color.RGBA{
		R: uint8(fr + 0.5),
		G: uint8(fg + 0.5),
		B: uint8(fb + 0.5),
		A: uint8(fa + 0.5),
	}
}

func bilinearAlpha(src *image.Alpha, x, y float32) color.Alpha {
	p := findLinearSrc(src.Bounds(), x, y)

	// Slice offsets for the surrounding pixels.
	off00 := src.PixOffset(p.low.X, p.low.Y)
	off01 := src.PixOffset(p.high.X, p.low.Y)
	off10 := src.PixOffset(p.low.X, p.high.Y)
	off11 := src.PixOffset(p.high.X, p.high.Y)

	fa := float32(src.Pix[off00]) * p.frac00
	fa += float32(src.Pix[off01]) * p.frac01
	fa += float32(src.Pix[off10]) * p.frac10
	fa += float32(src.Pix[off11]) * p.frac11

	return color.Alpha{A: uint8(fa + 0.5)}
}

type bilinearSrc struct {
	// Top-left and bottom-right interpolation sources
	low, high image.Point
	// Fraction of each pixel to take. The 0 suffix indicates
	// top/left, and the 1 suffix indicates bottom/right.
	frac00, frac01, frac10, frac11 float32
}

func floor(x float32) float32 { return float32(math.Floor(float64(x))) }
func ceil(x float32) float32  { return float32(math.Ceil(float64(x))) }

func findLinearSrc(b image.Rectangle, sx, sy float32) bilinearSrc {
	maxX := float32(b.Max.X)
	maxY := float32(b.Max.Y)
	minX := float32(b.Min.X)
	minY := float32(b.Min.Y)
	lowX := floor(sx - 0.5)
	lowY := floor(sy - 0.5)
	if lowX < minX {
		lowX = minX
	}
	if lowY < minY {
		lowY = minY
	}

	highX := ceil(sx - 0.5)
	highY := ceil(sy - 0.5)
	if highX >= maxX {
		highX = maxX - 1
	}
	if highY >= maxY {
		highY = maxY - 1
	}

	// In the variables below, the 0 suffix indicates top/left, and the
	// 1 suffix indicates bottom/right.

	// Center of each surrounding pixel.
	x00 := lowX + 0.5
	y00 := lowY + 0.5
	x01 := highX + 0.5
	y01 := lowY + 0.5
	x10 := lowX + 0.5
	y10 := highY + 0.5
	x11 := highX + 0.5
	y11 := highY + 0.5

	p := bilinearSrc{
		low:  image.Pt(int(lowX), int(lowY)),
		high: image.Pt(int(highX), int(highY)),
	}

	// Literally, edge cases. If we are close enough to the edge of
	// the image, curtail the interpolation sources.
	if lowX == highX && lowY == highY {
		p.frac00 = 1.0
	} else if sy-minY <= 0.5 && sx-minX <= 0.5 {
		p.frac00 = 1.0
	} else if maxY-sy <= 0.5 && maxX-sx <= 0.5 {
		p.frac11 = 1.0
	} else if sy-minY <= 0.5 || lowY == highY {
		p.frac00 = x01 - sx
		p.frac01 = sx - x00
	} else if sx-minX <= 0.5 || lowX == highX {
		p.frac00 = y10 - sy
		p.frac10 = sy - y00
	} else if maxY-sy <= 0.5 {
		p.frac10 = x11 - sx
		p.frac11 = sx - x10
	} else if maxX-sx <= 0.5 {
		p.frac01 = y11 - sy
		p.frac11 = sy - y01
	} else {
		p.frac00 = (x01 - sx) * (y10 - sy)
		p.frac01 = (sx - x00) * (y11 - sy)
		p.frac10 = (x11 - sx) * (sy - y00)
		p.frac11 = (sx - x10) * (sy - y01)
	}

	return p
}
