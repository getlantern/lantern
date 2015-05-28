package draw

import (
	"image"
)

// ReplXY returns the position of x inside the interval (min, max). That is,
// assuming (min, max) specify the base of an infinite tiling of the integer
// line, return the value of the image of x that appears in the interval.
func ReplXY(min, max, x int) int {
	sx := (x - min) % (max - min)
	if sx < 0 {
		sx += max - min
	}
	return sx + min
}

// Repl return the point corresponding to the image of p that appears inside
// the base rectangle r, which represents a tiling of the plane.
func Repl(r image.Rectangle, p image.Point) image.Point {
	return image.Point{
		ReplXY(r.Min.X, r.Max.X, p.X),
		ReplXY(r.Min.Y, r.Max.Y, p.Y),
	}
}
