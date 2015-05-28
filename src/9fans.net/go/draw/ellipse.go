package draw

import (
	"image"
)

func doellipse(cmd byte, dst *Image, c image.Point, xr, yr, thick int, src *Image, sp image.Point, alpha uint32, phi int, op Op) {
	setdrawop(dst.Display, op)
	a := dst.Display.bufimage(1 + 4 + 4 + 2*4 + 4 + 4 + 4 + 2*4 + 2*4)
	a[0] = cmd
	bplong(a[1:], dst.id)
	bplong(a[5:], src.id)
	bplong(a[9:], uint32(c.X))
	bplong(a[13:], uint32(c.Y))
	bplong(a[17:], uint32(xr))
	bplong(a[21:], uint32(yr))
	bplong(a[25:], uint32(thick))
	bplong(a[29:], uint32(sp.X))
	bplong(a[33:], uint32(sp.Y))
	bplong(a[37:], alpha)
	bplong(a[41:], uint32(phi))
}

// Ellipse draws, using SoverD, an ellipse with center c and horizontal and
// vertical semiaxes a and b, and thickness 1+2*thick. The source is aligned so
// sp corresponds to c.
func (dst *Image) Ellipse(c image.Point, a, b, thick int, src *Image, sp image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('e', dst, c, a, b, thick, src, sp, 0, 0, SoverD)
}

// EllipseOp draws an ellipse with center c and horizontal and vertical
// semiaxes a and b, and thickness 1+2*thick. The source is aligned so sp
// corresponds to c.
func (dst *Image) EllipseOp(c image.Point, a, b, thick int, src *Image, sp image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('e', dst, c, a, b, thick, src, sp, 0, 0, op)
}

// FillEllipse draws and fills, using SoverD, an ellipse with center c and
// horizontal and vertical semiaxes a and b, and thickness 1+2*thick. The
// source is aligned so sp corresponds to c.
func (dst *Image) FillEllipse(c image.Point, a, b, thick int, src *Image, sp image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('E', dst, c, a, b, thick, src, sp, 0, 0, SoverD)
}

// FillEllipseOp draws and fills ellipse with center c and horizontal and
// vertical semiaxes a and b, and thickness 1+2*thick. The source is aligned so
// sp corresponds to c.
func (dst *Image) FillEllipseOp(c image.Point, a, b, thick int, src *Image, sp image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('E', dst, c, a, b, thick, src, sp, 0, 0, op)
}

// Arc draws, using SoverD, the arc centered at c, with thickness 1+2*thick,
// using the specified source color. The arc starts at angle alpha and extends
// counterclockwise by phi; angles are measured in degrees from the x axis.
func (dst *Image) Arc(c image.Point, a, b, thick int, src *Image, sp image.Point, alpha, phi int) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('e', dst, c, a, b, thick, src, sp, uint32(alpha)|1<<31, phi, SoverD)
}

// ArcOp draws the arc centered at c, with thickness 1+2*thick, using the
// specified source color. The arc starts at angle alpha and extends
// counterclockwise by phi; angles are measured in degrees from the x axis.
func (dst *Image) ArcOp(c image.Point, a, b, thick int, src *Image, sp image.Point, alpha, phi int, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('e', dst, c, a, b, thick, src, sp, uint32(alpha)|1<<31, phi, op)
}

// FillArc draws and fills, using SoverD, the arc centered at c, with thickness
// 1+2*thick, using the specified source color. The arc starts at angle alpha
// and extends counterclockwise by phi; angles are measured in degrees from the
// x axis.
func (dst *Image) FillArc(c image.Point, a, b, thick int, src *Image, sp image.Point, alpha, phi int) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('E', dst, c, a, b, thick, src, sp, uint32(alpha)|1<<31, phi, SoverD)
}

// FillArcOp draws and fills the arc centered at c, with thickness 1+2*thick,
// using the specified source color. The arc starts at angle alpha and extends
// counterclockwise by phi; angles are measured in degrees from the x axis.
func (dst *Image) FillArcOp(c image.Point, a, b, thick int, src *Image, sp image.Point, alpha, phi int, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	doellipse('E', dst, c, a, b, thick, src, sp, uint32(alpha)|1<<31, phi, op)
}
