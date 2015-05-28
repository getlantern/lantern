package draw

import (
	"image"
	"image/color"
)

/*
 * Support for the Image type so it can satisfy the standard Color and Image interfaces.
 */

// At returns the standard Color value for the pixel at (x, y).
// If the location is outside the clipping rectangle, it returns color.Transparent.
// This operation does a round trip to the image server and can be expensive.
func (i *Image) At(x, y int) color.Color {
	if !(image.Point{x, y}.In(i.Clipr)) {
		return color.Transparent
	}
	if i.Repl && !(image.Point{x, y}.In(i.R)) {
		// Translate (x, y) to be within i.R.
		x = (x-i.R.Min.X)%(i.R.Max.X-i.R.Min.X) + i.R.Min.X
		y = (y-i.R.Min.Y)%(i.R.Max.Y-i.R.Min.Y) + i.R.Min.Y
	}
	var buf [4]byte
	_, err := i.Unload(image.Rect(x, y, x+1, y+1), buf[:])
	if err != nil {
		println("image.At: error in Unload: ", err.Error())
		return color.Transparent // As good a value as any.
	}
	// For multi-byte pixels, the ordering is little-endian.
	// For sub-byte pixels, the ordering is big-endian (0x80 is the first bit).
	// Three cheers for PCs.
	switch i.Pix {
	case GREY1:
		// CGrey, 1
		mask := uint8(1 << uint8(7-x&7))
		return Gray1{(buf[0] & mask) != 0}
	case GREY2:
		// CGrey, 2
		shift := uint(x&3) << 1
		// Place pixel at top of word.
		y := buf[0] << shift
		y &= 0xC0
		// Replicate throughout.
		y |= y >> 2
		y |= y >> 4
		return Gray2{y}
	case GREY4:
		// CGrey, 4
		shift := uint(x&1) << 2
		// Place pixel at top of word.
		y := buf[0] << shift
		y &= 0xF0
		// Replicate throughout.
		y |= y >> 4
		return Gray4{y}
	case GREY8:
		// CGrey, 8
		return color.Gray{buf[0]}
	case CMAP8:
		// CMap, 8
		return CMap8{buf[0]}
	case RGB15:
		v := uint16(buf[0]) | uint16(buf[1])<<8
		return CRGB15{v}
	case RGB16:
		v := uint16(buf[0]) | uint16(buf[1])<<8
		return CRGB16{v}
	case RGB24:
		// CRed, 8, CGreen, 8, CBlue, 8
		return color.RGBA{buf[2], buf[1], buf[0], 0xFF}
	case BGR24:
		// CBlue, 8, CGreen, 8, CRed, 8
		return color.RGBA{buf[0], buf[1], buf[2], 0xFF}
	case RGBA32:
		// CRed, 8, CGreen, 8, CBlue, 8, CAlpha, 8
		return color.RGBA{buf[3], buf[2], buf[1], buf[0]}
	case ARGB32:
		// CAlpha, 8, CRed, 8, CGreen, 8, CBlue, 8 // stupid VGAs
		return color.RGBA{buf[2], buf[1], buf[0], buf[3]}
	case ABGR32:
		// CAlpha, 8, CBlue, 8, CGreen, 8, CRed, 8
		return color.RGBA{buf[0], buf[1], buf[2], buf[3]}
	case XRGB32:
		// CIgnore, 8, CRed, 8, CGreen, 8, CBlue, 8
		return color.RGBA{buf[2], buf[1], buf[0], 0xFF}
	case XBGR32:
		// CIgnore, 8, CBlue, 8, CGreen, 8, CRed, 8
		return color.RGBA{buf[0], buf[1], buf[2], 0xFF}
	default:
		panic("unknown color")
	}
}

func (i *Image) Bounds() image.Rectangle {
	return i.Clipr
}

var (
	Gray1Model  color.Model = color.ModelFunc(gray1Model)
	Gray2Model  color.Model = color.ModelFunc(gray2Model)
	Gray4Model  color.Model = color.ModelFunc(gray4Model)
	CMap8Model  color.Model = color.ModelFunc(cmapModel)
	CRGB15Model color.Model = color.ModelFunc(crgb15Model)
	CRGB16Model color.Model = color.ModelFunc(crgb16Model)
)

// Gray1 represents a 1-bit black/white color.
type Gray1 struct {
	White bool
}

func (c Gray1) RGBA() (r, g, b, a uint32) {
	if c.White {
		return 0xffff, 0xffff, 0xffff, 0xffff
	}
	return 0, 0, 0, 0xffff
}

func gray1Model(c color.Color) color.Color {
	if _, ok := c.(Gray1); ok {
		return c
	}
	r, g, b, _ := c.RGBA()
	y := (299*r + 587*g + 114*b + 500) / 1000
	if y >= 128 {
		return color.Gray16{0xFFFF}
	}
	return color.Gray16{0}
}

// Gray2 represents a 2-bit grayscale color.
type Gray2 struct {
	Y uint8
}

func (c Gray2) RGBA() (r, g, b, a uint32) {
	y := uint32(c.Y) >> 6
	y |= y << 2
	y |= y << 4
	y |= y << 8
	return y, y, y, 0xffff
}

func gray2Model(c color.Color) color.Color {
	if _, ok := c.(Gray2); ok {
		return c
	}
	r, g, b, _ := c.RGBA()
	y := (299*r + 587*g + 114*b + 500) / 1000
	y >>= 6
	y |= y << 2
	y |= y << 4
	y |= y << 8
	return color.Gray16{uint16(0)}
}

// Gray4 represents a 4-bit grayscale color.
type Gray4 struct {
	Y uint8
}

func (c Gray4) RGBA() (r, g, b, a uint32) {
	y := uint32(c.Y) >> 4
	y |= y << 4
	y |= y << 8
	return y, y, y, 0xffff
}

func gray4Model(c color.Color) color.Color {
	if _, ok := c.(Gray4); ok {
		return c
	}
	r, g, b, _ := c.RGBA()
	y := (299*r + 587*g + 114*b + 500) / 1000
	y >>= 4
	y |= y << 4
	y |= y << 8
	return color.Gray16{uint16(0)}
}

// CMap8 represents an 8-bit color-mapped color with the standard Plan 9 color map.
type CMap8 struct {
	I uint8
}

func (c CMap8) RGBA() (r, g, b, a uint32) {
	ri, gi, bi := cmap2rgb(int(c.I))
	return uint32(ri), uint32(gi), uint32(bi), 0xffff
}

func cmapModel(c color.Color) color.Color {
	if _, ok := c.(CMap8); ok {
		return c
	}
	r32, g32, b32, a32 := c.RGBA()
	// Move to closest color.
	index := rgb2cmap(int(r32), int(g32), int(b32))
	r, g, b := cmap2rgb(index)
	// Lift alpha if necessary to keep premultiplication invariant.
	// The color is still in the map (there's no alpha in CMAP8).
	a := int(a32)
	if a < r {
		a = r
	}
	if a < g {
		a = g
	}
	if a < b {
		a = b
	}
	return color.RGBA{uint8(r >> 8), uint8(g >> 8), uint8(b >> 8), uint8(a >> 8)}
}

// CRGB15 represents a 15-bit 5-5-5 RGB color.
type CRGB15 struct {
	// CIgnore, 1, CRed, 5, CGreen, 5, CBlue, 5
	V uint16
}

func (c CRGB15) RGBA() (r, g, b, a uint32) {
	// Build a 5-bit value at the top of the low byte of each component.
	red := (c.V & 0x7C00) >> 7
	grn := (c.V & 0x03E0) >> 2
	blu := (c.V & 0x001F) << 3
	// Duplicate the high bits in the low bits.
	red |= red >> 5
	grn |= grn >> 5
	blu |= blu >> 5
	// Duplicate the whole value in the high byte.
	red |= red << 8
	grn |= grn << 8
	blu |= blu << 8
	return uint32(red), uint32(grn), uint32(blu), 0xffff
}

func crgb15Model(c color.Color) color.Color {
	if _, ok := c.(CRGB15); ok {
		return c
	}
	r, g, b, _ := c.RGBA()
	r = (r & 0xF800) >> 1
	g = (g & 0xF800) >> 6
	b = (b & 0xF800) >> 11
	return CRGB15{uint16(r | g | b)}
}

// CRGB16 represents a 16-bit 5-6-5 RGB color.
type CRGB16 struct {
	// CRed, 5, CGreen, 6, CBlue, 5
	V uint16
}

func (c CRGB16) RGBA() (r, g, b, a uint32) {
	// Build a 5- or 6-bit value at the top of the low byte of each component.
	red := (c.V & 0xF800) >> 8
	grn := (c.V & 0x07E0) >> 3
	blu := (c.V & 0x001F) << 3
	// Duplicate the high bits in the low bits.
	red |= red >> 5
	grn |= grn >> 6
	blu |= blu >> 5
	// Duplicate the whole value in the high byte.
	red |= red << 8
	grn |= grn << 8
	blu |= blu << 8
	return uint32(red), uint32(grn), uint32(blu), 0xffff
}

func crgb16Model(c color.Color) color.Color {
	if _, ok := c.(CRGB16); ok {
		return c
	}
	r, g, b, _ := c.RGBA()
	r = (r & 0xF800)
	g = (g & 0xFC00) >> 5
	b = (b & 0xF800) >> 11
	return CRGB15{uint16(r | g | b)}
}

// ColorModel returns the standard color model of the Image.
func (i *Image) ColorModel() color.Model {
	switch i.Pix {
	case GREY1:
		return Gray1Model
	case GREY2:
		return Gray2Model
	case GREY4:
		return Gray4Model
	case GREY8:
		return color.GrayModel
	case CMAP8:
		return CMap8Model
	case RGB15:
		return CRGB15Model
	case RGB16:
		return CRGB16Model
	case RGB24, RGBA32, ARGB32, ABGR32, XRGB32, XBGR32:
		return color.RGBAModel
	}
	panic("unknown image Pix type")
}
