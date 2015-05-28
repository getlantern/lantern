package draw

/*
 * Cobble fake font using existing subfont
 */

// MakeFont creates a Font from an existing subfont. The first character of the
// subfont will be rendered with rune value min.
func (subfont *Subfont) MakeFont(min rune) *Font {
	font := &Font{
		Display: subfont.Bits.Display,
		Name:    "<synthetic>",
		Height:  subfont.Height,
		Ascent:  subfont.Ascent,
		cache:   make([]cacheinfo, _NFCACHE+_NFLOOK),
		subf:    make([]cachesubf, _NFSUBF),
		age:     1,
		sub: []*cachefont{{
			min: min,
			max: min + rune(subfont.N) - 1,
		}},
	}
	font.subf[0].cf = font.sub[0]
	font.subf[0].f = subfont
	return font
}
