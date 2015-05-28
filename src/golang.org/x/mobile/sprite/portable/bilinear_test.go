// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package portable

import (
	"image"
	"image/color"
	"testing"
)

type interpTest struct {
	desc     string
	src      []uint8
	srcWidth int
	x, y     float32
	expect   uint8
}

func (p *interpTest) newSrc() *image.RGBA {
	b := image.Rect(0, 0, p.srcWidth, len(p.src)/p.srcWidth)
	src := image.NewRGBA(b)
	i := 0
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			src.SetRGBA(x, y, color.RGBA{
				R: p.src[i],
				G: p.src[i],
				B: p.src[i],
				A: 0xff,
			})
			i++
		}
	}
	return src
}

var interpTests = []interpTest{
	{
		desc:     "center of a single white pixel should match that pixel",
		src:      []uint8{0x00},
		srcWidth: 1,
		x:        0.5,
		y:        0.5,
		expect:   0x00,
	},
	{
		desc: "middle of a square is equally weighted",
		src: []uint8{
			0x00, 0xff,
			0xff, 0x00,
		},
		srcWidth: 2,
		x:        1.0,
		y:        1.0,
		expect:   0x80,
	},
	{
		desc: "center of a pixel is just that pixel",
		src: []uint8{
			0x00, 0xff,
			0xff, 0x00,
		},
		srcWidth: 2,
		x:        1.5,
		y:        0.5,
		expect:   0xff,
	},
	{
		desc: "asymmetry abounds",
		src: []uint8{
			0xaa, 0x11, 0x55,
			0xff, 0x95, 0xdd,
		},
		srcWidth: 3,
		x:        2.0,
		y:        1.0,
		expect:   0x76, // (0x11 + 0x55 + 0x95 + 0xdd) / 4
	},
}

func TestBilinear(t *testing.T) {
	for _, p := range interpTests {
		src := p.newSrc()

		c0 := bilinearGeneral(src, p.x, p.y)
		c0R, c0G, c0B, c0A := c0.RGBA()
		r := uint8(c0R >> 8)
		g := uint8(c0G >> 8)
		b := uint8(c0B >> 8)
		a := uint8(c0A >> 8)

		if r != g || r != b || a != 0xff {
			t.Errorf("expect channels to match, got %v", c0)
			continue
		}
		if r != p.expect {
			t.Errorf("%s: got 0x%02x want 0x%02x", p.desc, r, p.expect)
			continue
		}

		// fast path for *image.RGBA
		c1 := bilinearRGBA(src, p.x, p.y)
		if r != c1.R || g != c1.G || b != c1.B || a != c1.A {
			t.Errorf("%s: RGBA fast path mismatch got %v want %v", p.desc, c1, c0)
			continue
		}

		// fast path for *image.Alpha
		alpha := image.NewAlpha(src.Bounds())
		for y := src.Bounds().Min.Y; y < src.Bounds().Max.Y; y++ {
			for x := src.Bounds().Min.X; x < src.Bounds().Max.X; x++ {
				r, _, _, _ := src.At(x, y).RGBA()
				alpha.Set(x, y, color.Alpha{A: uint8(r >> 8)})
			}
		}
		c2 := bilinearAlpha(alpha, p.x, p.y)
		if c2.A != r {
			t.Errorf("%s: Alpha fast path mismatch got %v want %v", p.desc, c2, c0)
			continue
		}
	}
}

func TestBilinearSubImage(t *testing.T) {
	b0 := image.Rect(0, 0, 4, 4)
	src0 := image.NewRGBA(b0)
	b1 := image.Rect(1, 1, 3, 3)
	src1 := src0.SubImage(b1).(*image.RGBA)
	src1.Set(1, 1, color.RGBA{0x11, 0, 0, 0xff})
	src1.Set(2, 1, color.RGBA{0x22, 0, 0, 0xff})
	src1.Set(1, 2, color.RGBA{0x33, 0, 0, 0xff})
	src1.Set(2, 2, color.RGBA{0x44, 0, 0, 0xff})

	tests := []struct {
		x, y float32
		want uint32
	}{
		{1, 1, 0x11},
		{3, 1, 0x22},
		{1, 3, 0x33},
		{3, 3, 0x44},
		{2, 2, 0x2b},
	}

	for _, p := range tests {
		r, _, _, _ := bilinear(src1, p.x, p.y).RGBA()
		r >>= 8
		if r != p.want {
			t.Errorf("(%.0f, %.0f): got 0x%02x want 0x%02x", p.x, p.y, r, p.want)
		}
	}
}
