package draw

import (
	"image"
	"image/color"
	"testing"
)

type AtTest struct {
	im         *Image
	p          image.Point
	r, g, b, a uint8
}

var (
	r1  = image.Rect(0, 0, 1, 1)
	r2  = image.Rect(1, 1, 2, 2)
	p0  = image.Pt(0, 0)
	p1  = image.Pt(101, 101) // Far outside source of the replicated box.
	top = Color(0x884422FF)
	bot = Color(0x773311FF)
	gry = Color(0x30303030)
	AA  = Color(0xAAAAAAAA)
	AB  = Color(0xABABABAB)
	DD  = Color(0xDDDDDDDD)
)

var atTests = []AtTest{
	// GREY1
	{alloc(r1, GREY1, true, Black), p0, 0x00, 0x00, 0x00, 0xFF},
	{alloc(r1, GREY1, true, White), p0, 0xFF, 0xFF, 0xFF, 0xFF},
	// GREY2
	{alloc(r1, GREY2, true, Black), p0, 0x00, 0x00, 0x00, 0xFF},
	{alloc(r1, GREY2, true, White), p0, 0xFF, 0xFF, 0xFF, 0xFF},
	{alloc(r1, GREY2, true, AA), p0, 0xAA, 0xAA, 0xAA, 0xFF},
	{alloc(r2, GREY2, true, AA), p1, 0xAA, 0xAA, 0xAA, 0xFF},
	// GREY4
	{alloc(r1, GREY4, true, Black), p0, 0x00, 0x00, 0x00, 0xFF},
	{alloc(r1, GREY4, true, White), p0, 0xFF, 0xFF, 0xFF, 0xFF},
	{alloc(r1, GREY4, true, DD), p0, 0xDD, 0xDD, 0xDD, 0xFF},
	{alloc(r2, GREY4, true, AA), p1, 0xAA, 0xAA, 0xAA, 0xFF},
	// GREY8
	{alloc(r1, GREY8, true, Black), p0, 0x00, 0x00, 0x00, 0xFF},
	{alloc(r1, GREY8, true, White), p0, 0xFF, 0xFF, 0xFF, 0xFF},
	{alloc(r1, GREY8, true, AB), p0, 0xAB, 0xAB, 0xAB, 0xFF},
	{alloc(r1, GREY8, true, AA), p0, 0xAA, 0xAA, 0xAA, 0xFF},
	{alloc(r2, GREY8, true, AB), p1, 0xAB, 0xAB, 0xAB, 0xFF},
	// CMAP8 Cannot represent all 8-bit values accurately.
	{alloc(r1, CMAP8, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, CMAP8, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, CMAP8, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, CMAP8, true, top), p0, 0x88, 0x44, 0x00, 0xFF},
	{alloc(r1, CMAP8, true, bot), p0, 0x88, 0x44, 0x00, 0xFF},
	{alloc(r1, CMAP8, true, gry), p0, 0x33, 0x33, 0x33, 0xFF},
	{alloc(r2, CMAP8, true, gry), p1, 0x33, 0x33, 0x33, 0xFF},
	// RGB15 Cannot represent all 8-bit values accurately.
	{alloc(r1, RGB15, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, RGB15, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, RGB15, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, RGB15, true, top), p0, 0x8C, 0x42, 0x21, 0xFF},
	{alloc(r1, RGB15, true, bot), p0, 0x73, 0x31, 0x10, 0xFF},
	{alloc(r1, RGB15, true, gry), p0, 0x31, 0x31, 0x31, 0xFF},
	{alloc(r2, RGB15, true, top), p1, 0x8C, 0x42, 0x21, 0xFF},
	// RGB16 Cannot represent all 8-bit values accurately.
	{alloc(r1, RGB16, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, RGB16, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, RGB16, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, RGB16, true, top), p0, 0x8C, 0x45, 0x21, 0xFF},
	{alloc(r1, RGB16, true, bot), p0, 0x73, 0x30, 0x10, 0xFF},
	{alloc(r1, RGB16, true, gry), p0, 0x31, 0x30, 0x31, 0xFF},
	{alloc(r2, RGB16, true, top), p1, 0x8C, 0x45, 0x21, 0xFF},
	// RGB24
	{alloc(r1, RGB24, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, RGB24, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, RGB24, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, RGB24, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, RGB24, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, RGB24, true, gry), p0, 0x30, 0x30, 0x30, 0xFF},
	{alloc(r2, RGB24, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
	// BGR24
	{alloc(r1, BGR24, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, BGR24, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, BGR24, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, BGR24, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, BGR24, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, BGR24, true, gry), p0, 0x30, 0x30, 0x30, 0xFF},
	{alloc(r2, BGR24, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
	// RGBA32
	{alloc(r1, RGBA32, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, RGBA32, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, RGBA32, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, RGBA32, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, RGBA32, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, RGBA32, true, gry), p0, 0x30, 0x30, 0x30, 0x30},
	{alloc(r2, RGBA32, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
	// ARGB32
	{alloc(r1, ARGB32, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, ARGB32, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, ARGB32, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, ARGB32, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, ARGB32, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, ARGB32, true, gry), p0, 0x30, 0x30, 0x30, 0x30},
	{alloc(r2, ARGB32, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
	// ABGR32
	{alloc(r1, ABGR32, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, ABGR32, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, ABGR32, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, ABGR32, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, ABGR32, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, ABGR32, true, gry), p0, 0x30, 0x30, 0x30, 0x30},
	{alloc(r2, ABGR32, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
	// XRGB32
	{alloc(r1, XRGB32, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, XRGB32, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, XRGB32, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, XRGB32, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, XRGB32, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, XRGB32, true, gry), p0, 0x30, 0x30, 0x30, 0xFF},
	{alloc(r2, XRGB32, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
	// XBGR32
	{alloc(r1, XBGR32, true, Red), p0, 0xFF, 0x00, 0x00, 0xFF},
	{alloc(r1, XBGR32, true, Green), p0, 0x00, 0xFF, 0x00, 0xFF},
	{alloc(r1, XBGR32, true, Blue), p0, 0x00, 0x00, 0xFF, 0xFF},
	{alloc(r1, XBGR32, true, top), p0, 0x88, 0x44, 0x22, 0xFF},
	{alloc(r1, XBGR32, true, bot), p0, 0x77, 0x33, 0x11, 0xFF},
	{alloc(r1, XBGR32, true, gry), p0, 0x30, 0x30, 0x30, 0xFF},
	{alloc(r2, XBGR32, true, top), p1, 0x88, 0x44, 0x22, 0xFF},
}

func alloc(r image.Rectangle, pix Pix, repl bool, color Color) *Image {
	i, err := display().AllocImage(r, pix, repl, color)
	if err != nil {
		panic(err)
	}
	return i
}

func TestAt(t *testing.T) {
	for i, test := range atTests {
		r, g, b, a := test.im.At(test.p.X, test.p.Y).RGBA()
		got := color.RGBA{uint8(r), uint8(g), uint8(b), uint8(a)}
		want := color.RGBA{test.r, test.g, test.b, test.a}
		if got != want {
			t.Errorf("%d: got %x want %x", i, got, want)
		}
	}
}

func TestAtGrey1(t *testing.T) {
	col := func(x int) Color {
		c := Color(0x000000FF)
		if x&1 != 0 {
			c = Color(0xFFFFFFFF)
		}
		return c
	}
	i := alloc(image.Rect(0, 0, 4, 1), GREY1, false, 0)
	for x := 0; x < 4; x++ {
		bit := alloc(r1, GREY2, false, col(x))
		i.Draw(image.Rect(x, 0, x+1, 1), bit, nil, p0)
	}
	for x := 0; x < 4; x++ {
		r, g, b, a := i.At(x, 0).RGBA()
		got := color.RGBA{uint8(r), uint8(g), uint8(b), uint8(a)}
		want := color.RGBA{0, 0, 0, 0xFF}
		if x&1 != 0 {
			want = color.RGBA{0xFF, 0xFF, 0xFF, 0xFF}
		}
		if got != want {
			t.Errorf("%d: got %x want %x", x, got, want)
		}
	}
}

// Functions to create a pixel value that depends on x.
// The value is replicated so the same setting works for GREY2 and GREY4.
// For example, if x == 1, the pixel bits are 01010101, or 0x55.
func val(x int) int {
	c := x
	c |= c << 2
	return c | c<<4
}

func col(x int) Color {
	value := val(x)
	return Color(value<<24 | value<<16 | value<<8 | 0xFF)
}

func rgba(x int) color.Color {
	val := uint8(val(x))
	return color.RGBA{val, val, val, 0xFF}
}

func TestAtGrey2(t *testing.T) {
	i := alloc(image.Rect(0, 0, 4, 1), GREY2, false, 0)
	for x := 0; x < 4; x++ {
		bit := alloc(r1, GREY2, false, col(x))
		i.Draw(image.Rect(x, 0, x+1, 1), bit, nil, p0)
	}
	for x := 0; x < 4; x++ {
		r, g, b, a := i.At(x, 0).RGBA()
		got := color.RGBA{uint8(r), uint8(g), uint8(b), uint8(a)}
		want := rgba(x)
		if got != want {
			t.Errorf("%d: got %x want %x", x, got, want)
		}
	}
}

func TestAtGrey4(t *testing.T) {
	i := alloc(image.Rect(0, 0, 4, 1), GREY4, false, 0)
	for x := 0; x < 4; x++ {
		bit := alloc(r1, GREY4, false, col(x))
		i.Draw(image.Rect(x, 0, x+1, 1), bit, nil, p0)
	}
	for x := 0; x < 4; x++ {
		r, g, b, a := i.At(x, 0).RGBA()
		got := color.RGBA{uint8(r), uint8(g), uint8(b), uint8(a)}
		want := rgba(x)
		if got != want {
			t.Errorf("%d: got %x want %x", x, got, want)
		}
	}
}
