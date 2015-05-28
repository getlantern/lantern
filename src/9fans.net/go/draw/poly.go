package draw

import "image"

func addcoord(p []byte, oldx, newx int) int {
	dx := newx - oldx
	if uint(dx - -0x40) <= 0x7F {
		p[0] = byte(dx & 0x7F)
		return 1
	}
	p[0] = 0x80 | byte(newx&0x7F)
	p[1] = byte(newx >> 7)
	p[2] = byte(newx >> 15)
	return 3
}

func dopoly(cmd byte, dst *Image, pp []image.Point, end0, end1, radius int, src *Image, sp image.Point, op Op) {
	if len(pp) == 0 {
		return
	}

	setdrawop(dst.Display, op)
	m := 1 + 4 + 2 + 4 + 4 + 4 + 4 + 2*4 + len(pp)*2*3 // too much
	a := dst.Display.bufimage(m)                       // too much
	a[0] = cmd
	bplong(a[1:], uint32(dst.id))
	bpshort(a[5:], uint16(len(pp)-1))
	bplong(a[7:], uint32(end0))
	bplong(a[11:], uint32(end1))
	bplong(a[15:], uint32(radius))
	bplong(a[19:], uint32(src.id))
	bplong(a[23:], uint32(sp.X))
	bplong(a[27:], uint32(sp.Y))
	o := 31
	ox, oy := 0, 0
	for _, p := range pp {
		o += addcoord(a[o:], ox, p.X)
		o = addcoord(a[o:], oy, p.Y)
		ox, oy = p.X, p.Y
	}
	d := dst.Display
	d.buf = d.buf[:len(d.buf)-m+o]
}

// Poly draws the open polygon p in the specified source color, with ends as
// specified. The images are aligned so sp aligns with p[0]. The polygon is
// drawn using SoverD.
func (dst *Image) Poly(p []image.Point, end0, end1, radius int, src *Image, sp image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	dopoly('p', dst, p, end0, end1, radius, src, sp, SoverD)
}

// PolyOp draws the open polygon p in the specified source color, with ends as
// specified. The images are aligned so sp aligns with p[0].
func (dst *Image) PolyOp(p []image.Point, end0, end1, radius int, src *Image, sp image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	dopoly('p', dst, p, end0, end1, radius, src, sp, op)
}

// FillPoly fills the polygon p (which it closes if necessary) in the specified
// source color. The images are aligned so sp aligns with p[0]. The polygon is
// drawn using SoverD. The winding parameter resolves ambiguities; see the Plan
// 9 manual for details.
func (dst *Image) FillPoly(p []image.Point, end0, end1, radius int, src *Image, sp image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	dopoly('P', dst, p, end0, end1, radius, src, sp, SoverD)
}

// FillPolyOp fills the polygon p (which it closesif necessary) in the
// specified source color. The images are aligned so sp aligns with p[0]. The
// winding parameter resolves ambiguities; see the Plan 9 manual for details.
func (dst *Image) FillPolyOp(p []image.Point, end0, end1, radius int, src *Image, sp image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	dopoly('P', dst, p, end0, end1, radius, src, sp, op)
}
