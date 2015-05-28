package draw

import "image"

// Line draws a line in the source color from p0 to p1, of thickness
// 1+2*radius, with the specified ends, using SoverD. The source is aligned so
// sp corresponds to p0. See the Plan 9 documentation for more information.
func (dst *Image) Line(p0, p1 image.Point, end0, end1, radius int, src *Image, sp image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	dst.lineOp(p0, p1, end0, end1, radius, src, sp, SoverD)
}

// LineOp draws a line in the source color from p0 to p1, of thickness
// 1+2*radius, with the specified ends. The source is aligned so sp corresponds
// to p0. See the Plan 9 documentation for more information.
func (dst *Image) LineOp(p0, p1 image.Point, end0, end1, radius int, src *Image, sp image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	dst.lineOp(p0, p1, end0, end1, radius, src, sp, op)
}

func (dst *Image) lineOp(p0, p1 image.Point, end0, end1, radius int, src *Image, sp image.Point, op Op) {
	setdrawop(dst.Display, op)
	a := dst.Display.bufimage(1 + 4 + 2*4 + 2*4 + 4 + 4 + 4 + 4 + 2*4)
	a[0] = 'L'
	bplong(a[1:], uint32(dst.id))
	bplong(a[5:], uint32(p0.X))
	bplong(a[9:], uint32(p0.Y))
	bplong(a[13:], uint32(p1.X))
	bplong(a[17:], uint32(p1.Y))
	bplong(a[21:], uint32(end0))
	bplong(a[25:], uint32(end1))
	bplong(a[29:], uint32(radius))
	bplong(a[33:], uint32(src.id))
	bplong(a[37:], uint32(sp.X))
	bplong(a[41:], uint32(sp.Y))
}
