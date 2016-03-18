// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package portable

import (
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"io/ioutil"
	"math"
	"os"
	"testing"

	"golang.org/x/mobile/event/size"
	"golang.org/x/mobile/exp/f32"
	"golang.org/x/mobile/geom"
)

func TestAffine(t *testing.T) {
	f, err := os.Open("../../../testdata/testpattern.png")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	srcOrig, _, err := image.Decode(f)
	if err != nil {
		t.Fatal(err)
	}
	src := image.NewRGBA(srcOrig.Bounds())
	draw.Draw(src, src.Rect, srcOrig, srcOrig.Bounds().Min, draw.Src)

	const (
		pixW = 100
		pixH = 100
		ptW  = geom.Pt(50)
		ptH  = geom.Pt(50)
	)
	sz := size.Event{
		WidthPx:     pixW,
		HeightPx:    pixH,
		WidthPt:     ptW,
		HeightPt:    ptH,
		PixelsPerPt: float32(pixW) / float32(ptW),
	}

	got := image.NewRGBA(image.Rect(0, 0, pixW, pixH))
	blue := image.NewUniform(color.RGBA{B: 0xff, A: 0xff})
	draw.Draw(got, got.Bounds(), blue, image.Point{}, draw.Src)

	b := src.Bounds()
	b.Min.X += 10
	b.Max.Y /= 2

	var a f32.Affine
	a.Identity()
	a.Scale(&a, sz.PixelsPerPt, sz.PixelsPerPt)
	a.Translate(&a, 0, 24)
	a.Rotate(&a, float32(math.Asin(12./20)))
	// See commentary in the render method defined in portable.go.
	a.Scale(&a, 40/float32(b.Dx()), 20/float32(b.Dy()))
	a.Inverse(&a)

	affine(got, src, b, nil, &a, draw.Over)

	ptTopLeft := geom.Point{0, 24}
	ptBottomRight := geom.Point{12 + 32, 16}

	drawCross(got, 0, 0)
	drawCross(got, int(ptTopLeft.X.Px(sz.PixelsPerPt)), int(ptTopLeft.Y.Px(sz.PixelsPerPt)))
	drawCross(got, int(ptBottomRight.X.Px(sz.PixelsPerPt)), int(ptBottomRight.Y.Px(sz.PixelsPerPt)))
	drawCross(got, pixW-1, pixH-1)

	const wantPath = "../../../testdata/testpattern-window.png"
	f, err = os.Open(wantPath)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	wantSrc, _, err := image.Decode(f)
	if err != nil {
		t.Fatal(err)
	}
	want, ok := wantSrc.(*image.RGBA)
	if !ok {
		b := wantSrc.Bounds()
		want = image.NewRGBA(b)
		draw.Draw(want, b, wantSrc, b.Min, draw.Src)
	}

	if !imageEq(got, want) {
		gotPath, err := writeTempPNG("testpattern-window-got", got)
		if err != nil {
			t.Fatal(err)
		}
		t.Errorf("got\n%s\nwant\n%s", gotPath, wantPath)
	}
}

func TestAffineMask(t *testing.T) {
	f, err := os.Open("../../../testdata/testpattern.png")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	srcOrig, _, err := image.Decode(f)
	if err != nil {
		t.Fatal(err)
	}
	b := srcOrig.Bounds()
	src := image.NewRGBA(b)
	draw.Draw(src, src.Rect, srcOrig, b.Min, draw.Src)
	mask := image.NewAlpha(b)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			mask.Set(x, y, color.Alpha{A: uint8(x - b.Min.X)})
		}
	}
	want := image.NewRGBA(b)
	draw.DrawMask(want, want.Rect, src, b.Min, mask, b.Min, draw.Src)

	a := new(f32.Affine)
	a.Identity()
	got := image.NewRGBA(b)
	affine(got, src, b, mask, a, draw.Src)

	if !imageEq(got, want) {
		gotPath, err := writeTempPNG("testpattern-mask-got", got)
		if err != nil {
			t.Fatal(err)
		}
		wantPath, err := writeTempPNG("testpattern-mask-want", want)
		if err != nil {
			t.Fatal(err)
		}
		t.Errorf("got\n%s\nwant\n%s", gotPath, wantPath)
	}
}

func writeTempPNG(prefix string, m image.Image) (string, error) {
	f, err := ioutil.TempFile("", prefix+"-")
	if err != nil {
		return "", err
	}
	f.Close()
	path := f.Name() + ".png"
	f, err = os.Create(path)
	if err != nil {
		return "", err
	}
	if err := png.Encode(f, m); err != nil {
		f.Close()
		return "", err
	}
	return path, f.Close()
}

func drawCross(m *image.RGBA, x, y int) {
	c := color.RGBA{0xff, 0, 0, 0xff} // red
	m.SetRGBA(x+0, y-2, c)
	m.SetRGBA(x+0, y-1, c)
	m.SetRGBA(x-2, y+0, c)
	m.SetRGBA(x-1, y+0, c)
	m.SetRGBA(x+0, y+0, c)
	m.SetRGBA(x+1, y+0, c)
	m.SetRGBA(x+2, y+0, c)
	m.SetRGBA(x+0, y+1, c)
	m.SetRGBA(x+0, y+2, c)
}

func eqEpsilon(x, y uint8) bool {
	const epsilon = 9
	return x-y < epsilon || y-x < epsilon
}

func colorEq(c0, c1 color.RGBA) bool {
	return eqEpsilon(c0.R, c1.R) && eqEpsilon(c0.G, c1.G) && eqEpsilon(c0.B, c1.B) && eqEpsilon(c0.A, c1.A)
}

func imageEq(m0, m1 *image.RGBA) bool {
	b0 := m0.Bounds()
	b1 := m1.Bounds()
	if b0 != b1 {
		return false
	}
	badPx := 0
	for y := b0.Min.Y; y < b0.Max.Y; y++ {
		for x := b0.Min.X; x < b0.Max.X; x++ {
			c0, c1 := m0.At(x, y).(color.RGBA), m1.At(x, y).(color.RGBA)
			if !colorEq(c0, c1) {
				badPx++
			}
		}
	}
	badFrac := float64(badPx) / float64(b0.Dx()*b0.Dy())
	return badFrac < 0.01
}
