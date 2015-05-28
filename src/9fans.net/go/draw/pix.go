package draw

import (
	"fmt"
)

// A Color represents an RGBA value, 8 bits per element. Red is the high 8
// bits, green the next 8 and so on.
type Color uint32

const (
	Opaque        Color = 0xFFFFFFFF
	Transparent   Color = 0x00000000 /* only useful for allocimage memfillcolor */
	Black         Color = 0x000000FF
	White         Color = 0xFFFFFFFF
	Red           Color = 0xFF0000FF
	Green         Color = 0x00FF00FF
	Blue          Color = 0x0000FFFF
	Cyan          Color = 0x00FFFFFF
	Magenta       Color = 0xFF00FFFF
	Yellow        Color = 0xFFFF00FF
	Paleyellow    Color = 0xFFFFAAFF
	Darkyellow    Color = 0xEEEE9EFF
	Darkgreen     Color = 0x448844FF
	Palegreen     Color = 0xAAFFAAFF
	Medgreen      Color = 0x88CC88FF
	Darkblue      Color = 0x000055FF
	Palebluegreen Color = 0xAAFFFFFF
	Paleblue      Color = 0x0000BBFF
	Bluegreen     Color = 0x008888FF
	Greygreen     Color = 0x55AAAAFF
	Palegreygreen Color = 0x9EEEEEFF
	Yellowgreen   Color = 0x99994CFF
	Medblue       Color = 0x000099FF
	Greyblue      Color = 0x005DBBFF
	Palegreyblue  Color = 0x4993DDFF
	Purpleblue    Color = 0x8888CCFF

	Notacolor Color = 0xFFFFFF00
	Nofill    Color = Notacolor
)

// Pix represents a pixel format described simple notation: r8g8b8 for RGB24, m8
// for color-mapped 8 bits, etc. The representation is 8 bits per channel,
// starting at the low end, with each byte represnted as a channel specifier
// (CRed etc.) in the high 4 bits and the number of pixels in the low 4 bits.
type Pix uint32

const (
	CRed = iota
	CGreen
	CBlue
	CGrey
	CAlpha
	CMap
	CIgnore
	NChan
)

var (
	GREY1  Pix = MakePix(CGrey, 1)
	GREY2  Pix = MakePix(CGrey, 2)
	GREY4  Pix = MakePix(CGrey, 4)
	GREY8  Pix = MakePix(CGrey, 8)
	CMAP8  Pix = MakePix(CMap, 8)
	RGB15  Pix = MakePix(CIgnore, 1, CRed, 5, CGreen, 5, CBlue, 5)
	RGB16      = MakePix(CRed, 5, CGreen, 6, CBlue, 5)
	RGB24      = MakePix(CRed, 8, CGreen, 8, CBlue, 8)
	BGR24      = MakePix(CBlue, 8, CGreen, 8, CRed, 8)
	RGBA32     = MakePix(CRed, 8, CGreen, 8, CBlue, 8, CAlpha, 8)
	ARGB32     = MakePix(CAlpha, 8, CRed, 8, CGreen, 8, CBlue, 8) // stupid VGAs
	ABGR32     = MakePix(CAlpha, 8, CBlue, 8, CGreen, 8, CRed, 8)
	XRGB32     = MakePix(CIgnore, 8, CRed, 8, CGreen, 8, CBlue, 8)
	XBGR32     = MakePix(CIgnore, 8, CBlue, 8, CGreen, 8, CRed, 8)
)

// MakePix returns a Pix by placing the successive integers into 4-bit nibbles, low bits first.
func MakePix(list ...int) Pix {
	var p Pix
	for _, x := range list {
		p <<= 4
		p |= Pix(x)
	}
	return p
}

// ParsePix is the reverse of String, turning a pixel string such as "r8g8b8" into a Pix value.
func ParsePix(s string) (Pix, error) {
	var p Pix
	s0 := s
	if len(s) > 8 {
		goto Malformed
	}
	for ; len(s) > 0; s = s[2:] {
		if len(s) == 1 {
			goto Malformed
		}
		p <<= 4
		switch s[0] {
		default:
			goto Malformed
		case 'r':
			p |= CRed
		case 'g':
			p |= CGreen
		case 'b':
			p |= CBlue
		case 'a':
			p |= CAlpha
		case 'k':
			p |= CGrey
		case 'm':
			p |= CMap
		case 'x':
			p |= CIgnore
		}
		p <<= 4
		if s[1] < '1' || s[1] > '8' {
			goto Malformed
		}
		p |= Pix(s[1] - '0')
	}
	return p, nil

Malformed:
	return 0, fmt.Errorf("malformed pix descriptor %q", s0)
}

// String prints the pixel format as a string: "r8g8b8" for example.
func (p Pix) String() string {
	var buf [8]byte
	i := len(buf)
	if p == 0 {
		return "0"
	}
	for p > 0 {
		i -= 2
		buf[i] = "rgbkamxzzzzzzzzz"[(p>>4)&15]
		buf[i+1] = "0123456789abcdef"[p&15]
		p >>= 8
	}
	return string(buf[i:])
}

func (p Pix) Depth() int {
	n := 0
	for p > 0 {
		n += int(p & 15)
		p >>= 8
	}
	return n
}
