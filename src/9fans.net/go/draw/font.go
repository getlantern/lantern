package draw

import (
	"fmt"
	"image"
	"os"
	"sync"
	"unicode/utf8"
)

// A Font represents a font that may be used to draw on the display.
// A Font is constructed by reading a font file that describes how to
// create a full font from a collection of subfonts, each of which
// covers a section of the Unicode code space.
type Font struct {
	Display *Display
	Name    string // name, typically from file.
	Height  int    // max height of image, interline spacing
	Ascent  int    // top of image to baseline

	mu         sync.Mutex // only used if Display == nil
	width      int        // widest so far; used in caching only
	age        uint32     // increasing counter; used for LUR
	maxdepth   int        // maximum depth of all loaded subfonts
	cache      []cacheinfo
	subf       []cachesubf
	sub        []*cachefont // as read from file
	cacheimage *Image
}

func (f *Font) lock() {
	if f.Display != nil {
		f.Display.mu.Lock()
	} else {
		f.mu.Lock()
	}
}

func (f *Font) unlock() {
	if f.Display != nil {
		f.Display.mu.Unlock()
	} else {
		f.mu.Unlock()
	}
}

type cachefont struct {
	min         rune
	max         rune
	offset      int
	name        string
	subfontname string
}

type cacheinfo struct {
	x     uint16
	width uint8
	left  int8
	value rune
	age   uint32
}

type cachesubf struct {
	age uint32
	cf  *cachefont
	f   *Subfont
}

// A Subfont represents a subfont, mapping a section of the Unicode code space to a set of glyphs.
type Subfont struct {
	Name   string     // Name of the subfont, typically the file from which it was read.
	N      int        // Number of characters in the subfont.
	Height int        // Inter-line spacing.
	Ascent int        // Height above the baseline.
	Info   []Fontchar // Character descriptions.
	Bits   *Image     // Image holding the glyphs.
	ref    int
}

// A Fontchar descibes one character glyph in a font (really a subfont).
type Fontchar struct {
	X      int   // x position in the image holding the glyphs.
	Top    uint8 // first non-zero scan line.
	Bottom uint8 // last non-zero scan line.
	Left   int8  // offset of baseline.
	Width  uint8 // width of baseline.
}

const (
	/* starting values */
	_LOG2NFCACHE = 6
	_NFCACHE     = (1 << _LOG2NFCACHE) /* #chars cached */
	_NFLOOK      = 5                   /* #chars to scan in cache */
	_NFSUBF      = 2                   /* #subfonts to cache */
	/* max value */
	_MAXFCACHE = 1024 + _NFLOOK /* upper limit */
	_MAXSUBF   = 50             /* generous upper limit */
	/* deltas */
	_DSUBF = 4
	/* expiry ages */
	_SUBFAGE  = 10000
	_CACHEAGE = 10000
)

const pjw = 0 /* use NUL==pjw for invisible characters */

func cachechars(f *Font, in *input, cp []uint16, max int) (n, wid int, subfontname string) {
	var i int
	//println("cachechars", i<max, in.done)
Loop:
	for ; i < max && !in.done; in.next() {
		r := in.ch
		var (
			c, tc              *cacheinfo
			a                  uint32
			sh, esh, h, th, ld int
		)

		sh = (17 * int(r)) & (len(f.cache) - _NFLOOK - 1)
		esh = sh + _NFLOOK
		h = sh
		for h < esh {
			c = &f.cache[h]
			if c.value == r && c.age > 0 {
				goto Found
			}
			h++
		}

		/*
		 * Not found; toss out oldest entry
		 */
		a = ^uint32(0)
		th = sh
		for th < esh {
			tc = &f.cache[th]
			if tc.age < a {
				a = tc.age
				h = th
				c = tc
			}
			th++
		}

		if a != 0 && f.age-a < 500 { // kicking out too recent; resize
			nc := 2*(len(f.cache)-_NFLOOK) + _NFLOOK
			if nc <= _MAXFCACHE {
				if i == 0 {
					fontresize(f, f.width, nc, f.maxdepth)
				}
				// else flush first; retry will resize
				break Loop
			}
		}

		if c.age == f.age { // flush pending string output
			break Loop
		}

		ld, subfontname = loadchar(f, r, c, h, i > 0)
		if ld <= 0 {
			if ld == 0 {
				continue Loop
			}
			break Loop
		}
		c = &f.cache[h]

	Found:
		//println("FOUND")
		wid += int(c.width)
		c.age = f.age
		cp[i] = uint16(h)
		i++
	}
	return i, wid, subfontname
}

func agefont(f *Font) {
	f.age++
	if f.age == 65536 {
		/*
		 * Renormalize ages
		 */
		for i := range f.cache {
			c := &f.cache[i]
			if c.age > 0 {
				c.age >>= 2
				c.age++
			}
		}
		for i := range f.subf {
			s := &f.subf[i]
			if s.age > 0 {
				if s.age < _SUBFAGE && s.cf.name != "" {
					/* clean up */
					if f.Display == nil || s.f != f.Display.DefaultSubfont {
						s.f.free()
					}
					s.cf = nil
					s.f = nil
					s.age = 0
				} else {
					s.age >>= 2
					s.age++
				}
			}
		}
		f.age = (65536 >> 2) + 1
	}
}

func cf2subfont(cf *cachefont, f *Font) (*Subfont, error) {
	name := cf.subfontname
	if name == "" {
		depth := 0
		if f.Display != nil {
			if f.Display.ScreenImage != nil {
				depth = f.Display.ScreenImage.Depth
			}
		} else {
			depth = 8
		}
		name = subfontname(cf.name, f.Name, depth)
		if name == "" {
			return nil, fmt.Errorf("unknown subfont")
		}
		cf.subfontname = name
	}
	sf := lookupsubfont(f.Display, name)
	return sf, nil
}

// return 1 if load succeeded, 0 if failed, -1 if must retry
func loadchar(f *Font, r rune, c *cacheinfo, h int, noflush bool) (int, string) {
	var (
		i, oi, wid, top, bottom int
		pic                     rune
		fi                      []Fontchar
		cf                      *cachefont
		subf                    *cachesubf
		b                       []byte
	)

	pic = r
Again:
	for i, cf = range f.sub {
		if cf.min <= pic && pic <= cf.max {
			goto Found
		}
	}
TryPJW:
	if pic != pjw {
		pic = pjw
		goto Again
	}
	return 0, ""

Found:
	/*
	 * Choose exact or oldest
	 */
	oi = 0
	for i := range f.subf {
		subf = &f.subf[i]
		if cf == subf.cf {
			goto Found2
		}
		if subf.age < f.subf[oi].age {
			oi = i
		}
	}
	subf = &f.subf[oi]

	if subf.f != nil {
		if f.age-subf.age > _SUBFAGE || len(f.subf) > _MAXSUBF {
			// ancient data; toss
			subf.f.free()
			subf.cf = nil
			subf.f = nil
			subf.age = 0
		} else { // too recent; grow instead
			of := f.subf
			f.subf = make([]cachesubf, len(f.subf)+_DSUBF)
			copy(f.subf, of)
			subf = &f.subf[len(of)]
		}
	}

	subf.age = 0
	subf.cf = nil
	subf.f, _ = cf2subfont(cf, f)
	if subf.f == nil {
		if cf.subfontname == "" {
			goto TryPJW
		}
		return -1, cf.subfontname
	}

	subf.cf = cf
	if subf.f.Ascent > f.Ascent && f.Display != nil {
		/* should print something? this is a mistake in the font file */
		/* must prevent c.top from going negative when loading cache */
		d := subf.f.Ascent - f.Ascent
		b := subf.f.Bits
		b.draw(b.R, b, nil, b.R.Min.Add(image.Pt(0, d)))
		b.draw(image.Rect(b.R.Min.X, b.R.Max.Y-d, b.R.Max.X, b.R.Max.Y), f.Display.Black, nil, b.R.Min)
		for i := 0; i < subf.f.N; i++ {
			t := int(subf.f.Info[i].Top) - d
			if t < 0 {
				t = 0
			}
			subf.f.Info[i].Top = uint8(t)
			t = int(subf.f.Info[i].Bottom) - d
			if t < 0 {
				t = 0
			}
			subf.f.Info[i].Bottom = uint8(t)
		}
		subf.f.Ascent = f.Ascent
	}

Found2:
	subf.age = f.age

	/* possible overflow here, but works out okay */
	pic += rune(cf.offset)
	pic -= cf.min
	if int(pic) >= subf.f.N {
		goto TryPJW
	}
	fi = subf.f.Info[pic : pic+2]
	if fi[0].Width == 0 {
		goto TryPJW
	}
	wid = fi[1].X - fi[0].X
	if f.width < wid || f.width == 0 || f.maxdepth < subf.f.Bits.Depth {
		/*
		 * Flush, free, reload (easier than reformatting f.b)
		 */
		if noflush {
			return -1, ""
		}
		if f.width < wid {
			f.width = wid
		}
		if f.maxdepth < subf.f.Bits.Depth {
			f.maxdepth = subf.f.Bits.Depth
		}
		i = fontresize(f, f.width, len(f.cache), f.maxdepth)
		if i <= 0 {
			return i, ""
		}
		/* c is still valid as didn't reallocate f.cache */
	}
	c.value = r
	top = int(fi[0].Top) + (f.Ascent - subf.f.Ascent)
	bottom = int(fi[0].Bottom) + (f.Ascent - subf.f.Ascent)
	c.width = fi[0].Width
	c.x = uint16(h * int(f.width))
	c.left = fi[0].Left
	if f.Display == nil {
		return 1, ""
	}
	f.Display.flush(false) /* flush any pending errors */
	b = f.Display.bufimage(37)
	b[0] = 'l'
	bplong(b[1:], uint32(f.cacheimage.id))
	bplong(b[5:], uint32(subf.f.Bits.id))
	bpshort(b[9:], uint16(h))
	bplong(b[11:], uint32(c.x))
	bplong(b[15:], uint32(top))
	bplong(b[19:], uint32(int(c.x)+int(fi[1].X-fi[0].X)))
	bplong(b[23:], uint32(bottom))
	bplong(b[27:], uint32(fi[0].X))
	bplong(b[31:], uint32(fi[0].Top))
	b[35] = byte(fi[0].Left)
	b[36] = fi[0].Width
	return 1, ""
}

// return whether resize succeeded && f.cache is unchanged
func fontresize(f *Font, wid, ncache, depth int) int {
	var (
		ret int
		new *Image
		b   []byte
		d   *Display
		err error
	)

	if depth <= 0 {
		depth = 1
	}

	d = f.Display
	if d == nil {
		goto Nodisplay
	}
	new, err = d.allocImage(image.Rect(0, 0, ncache*wid, f.Height), MakePix(CGrey, depth), false, 0)
	if err != nil {
		fmt.Fprintf(os.Stderr, "font cache resize failed\n")
		panic("resize")
	}
	d.flush(false) // flush any pending errors
	b = d.bufimage(1 + 4 + 4 + 1)
	b[0] = 'i'
	bplong(b[1:], new.id)
	bplong(b[5:], uint32(ncache))
	b[9] = byte(f.Ascent)
	if err := d.flush(false); err != nil {
		fmt.Fprintf(os.Stderr, "resize: init failed\n")
		new.free()
		goto Return
	}
	f.cacheimage.free()
	f.cacheimage = new

Nodisplay:
	f.width = wid
	f.maxdepth = depth
	ret = 1
	if len(f.cache) != ncache {
		f.cache = make([]cacheinfo, ncache)
	}

Return:
	for i := range f.cache {
		f.cache[i] = cacheinfo{}
	}
	return ret
}

// An input can read a rune at a time from a string, []byte, or []rune.
type input struct {
	mode int
	s    string
	b    []byte
	r    []rune
	size int
	ch   rune
	done bool
}

func (in *input) init(s string, b []byte, r []rune) {
	//println("init:", s)
	in.s = s
	in.b = b
	in.r = r
	in.mode = 0
	if len(in.s) == 0 {
		in.mode = 1
		if len(in.b) == 0 {
			in.mode = 2
		}
	}

	in.next()
}

func (in *input) next() {
	switch in.mode {
	case 0:
		in.s = in.s[in.size:]
		if len(in.s) == 0 {
			in.done = true
			return
		}
		in.ch, in.size = utf8.DecodeRuneInString(in.s)
	case 1:
		in.b = in.b[in.size:]
		if len(in.b) == 0 {
			in.done = true
			return
		}
		in.ch, in.size = utf8.DecodeRune(in.b)
	case 2:
		in.r = in.r[in.size:]
		if len(in.r) == 0 {
			in.done = true
			return
		}
		in.ch = in.r[0]
		in.size = 1
	}
	//println("next is ", in.ch, in.done)
}
