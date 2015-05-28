package draw

import (
	"fmt"
	"image"
	"os"
)

func stringnwidth(f *Font, s string, b []byte, r []rune) int {
	const Max = 64
	cbuf := make([]uint16, Max)
	var in input
	in.init(s, b, r)
	twid := 0
	for !in.done {
		max := Max
		n := 0
		var sf *Subfont
		var l, wid int
		var subfontname string
		for {
			if l, wid, subfontname = cachechars(f, &in, cbuf, max); l > 0 {
				break
			}
			if n++; n > 10 {
				r := in.ch
				name := f.Name
				if name == "" {
					name = "unnamed font"
				}
				sf.free()
				fmt.Fprintf(os.Stderr, "stringwidth: bad character set for rune %U in %s\n", r, name)
				return twid
			}
			if subfontname != "" {
				sf.free()
				var err error
				sf, err = getsubfont(f.Display, subfontname)
				if err != nil {
					if f.Display != nil && f != f.Display.DefaultFont {
						f = f.Display.DefaultFont
						continue
					}
					break
				}
				/*
				 * must not free sf until cachechars has found it in the cache
				 * and picked up its own reference.
				 */
			}
		}
		sf.free()
		agefont(f)
		twid += wid
	}
	return twid
}

// StringWidth returns the number of horizontal pixels that would be occupied
// by the string if it were drawn using the font.
func (f *Font) StringWidth(s string) int {
	f.lock()
	defer f.unlock()
	return stringnwidth(f, s, nil, nil)
}

// ByteWidth returns the number of horizontal pixels that would be occupied by
// the byte slice if it were drawn using the font.
func (f *Font) BytesWidth(b []byte) int {
	f.lock()
	defer f.unlock()
	return stringnwidth(f, "", b, nil)
}

// RuneWidth returns the number of horizontal pixels that would be occupied by
// the rune slice if it were drawn using the font.
func (f *Font) RunesWidth(r []rune) int {
	f.lock()
	defer f.unlock()
	return stringnwidth(f, "", nil, r)
}

// StringSize returns the number of horizontal and vertical pixels that would
// be occupied by the string if it were drawn using the font.
func (f *Font) StringSize(s string) image.Point {
	return image.Pt(f.StringWidth(s), f.Height)
}

// ByteSize returns the number of horizontal and vertical pixels that would be
// occupied by the byte slice if it were drawn using the font.
func (f *Font) BytesSize(b []byte) image.Point {
	return image.Pt(f.BytesWidth(b), f.Height)
}

// RuneSize returns the number of horizontal and vertical pixels that would be
// occupied by the rune slice if it were drawn using the font.
func (f *Font) RunesSize(r []rune) image.Point {
	return image.Pt(f.RunesWidth(r), f.Height)
}
