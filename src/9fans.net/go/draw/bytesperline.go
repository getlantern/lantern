package draw

import "image"

// WordsPerLine returns the number of 32-bit words touched by a scan line of
// the rectangle of specified depth.
func WordsPerLine(r image.Rectangle, depth int) int {
	return unitsPerLine(r, depth, 32)
}

// BytesPerLine returns the number of 8-bit bytes touched by a scan line of
// the rectangle of specified depth.
func BytesPerLine(r image.Rectangle, depth int) int {
	return unitsPerLine(r, depth, 8)
}

func unitsPerLine(r image.Rectangle, depth, bitsperunit int) int {
	if depth <= 0 || depth > 32 {
		panic("invalid depth")
	}

	var l int
	if r.Min.X >= 0 {
		l = (r.Max.X*depth + bitsperunit - 1) / bitsperunit
		l -= (r.Min.X * depth) / bitsperunit
	} else {
		// make positive before divide
		t := (-r.Min.X*depth + bitsperunit - 1) / bitsperunit
		l = t + (r.Max.X*depth+bitsperunit-1)/bitsperunit
	}
	return l
}
