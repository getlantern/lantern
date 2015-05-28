// Package draw is a port of Plan 9's libdraw to Go.
// It connects to the 'devdraw' binary built as part of Plan 9 from User Space (http://swtch.com/plan9port/).
// All graphics operations are done in the remote server. The functions
// in this package typically send a message to the server.
//
// For background, see http://plan9.bell-labs.com/magic/man2html/2/graphics and associated pages
// for documentation. Not everything is implemented.
//
// Notable Changes
//
// The pixel descriptions like "r8g8b8" and their integer equivalents are referred to as chans in Plan 9.
// To avoid confusion, this package refers to them as type Pix.
//
// Most top-level functions are methods on an appropriate type (Display, Image, Font).
//
// Getwindow, called during resize, is now Display.Attach.
//
package draw // import "9fans.net/go/draw"

import (
	"image"
)

// Op represents a Porter-Duff compositing operator.
type Op int

const (
	/* Porter-Duff compositing operators */
	Clear Op = 0

	SinD  Op = 8
	DinS  Op = 4
	SoutD Op = 2
	DoutS Op = 1

	S      = SinD | SoutD
	SoverD = SinD | SoutD | DoutS
	SatopD = SinD | DoutS
	SxorD  = SoutD | DoutS

	D      = DinS | DoutS
	DoverS = DinS | DoutS | SoutD
	DatopS = DinS | SoutD
	DxorS  = DoutS | SoutD /* == SxorD */

	Ncomp = 12
)

func setdrawop(d *Display, op Op) {
	if op != SoverD {
		a := d.bufimage(2)
		a[0] = 'O'
		a[1] = byte(op)
	}
}

func draw(dst *Image, r image.Rectangle, src *Image, p0 image.Point, mask *Image, p1 image.Point, op Op) {
	setdrawop(dst.Display, op)

	a := dst.Display.bufimage(1 + 4 + 4 + 4 + 4*4 + 2*4 + 2*4)
	if src == nil {
		src = dst.Display.Black
	}
	if mask == nil {
		mask = dst.Display.Opaque
	}
	a[0] = 'd'
	bplong(a[1:], dst.id)
	bplong(a[5:], src.id)
	bplong(a[9:], mask.id)
	bplong(a[13:], uint32(r.Min.X))
	bplong(a[17:], uint32(r.Min.Y))
	bplong(a[21:], uint32(r.Max.X))
	bplong(a[25:], uint32(r.Max.Y))
	bplong(a[29:], uint32(p0.X))
	bplong(a[33:], uint32(p0.Y))
	bplong(a[37:], uint32(p1.X))
	bplong(a[41:], uint32(p1.Y))
}

func (dst *Image) draw(r image.Rectangle, src, mask *Image, p1 image.Point) {
	draw(dst, r, src, p1, mask, p1, SoverD)
}

// Draw copies the source image with upper left corner p1 to the destination
// rectangle r, through the specified mask using operation SoverD. The
// coordinates are aligned so p1 in src and mask both correspond to r.min in
// the destination.
func (dst *Image) Draw(r image.Rectangle, src, mask *Image, p1 image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	draw(dst, r, src, p1, mask, p1, SoverD)
}

// DrawOp copies the source image with upper left corner p1 to the destination
// rectangle r, through the specified mask using the specified operation. The
// coordinates are aligned so p1 in src and mask both correspond to r.min in
// the destination.
func (dst *Image) DrawOp(r image.Rectangle, src, mask *Image, p1 image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	draw(dst, r, src, p1, mask, p1, op)
}

// GenDraw copies the source image with upper left corner p1 to the destination
// rectangle r, through the specified mask using operation SoverD. The
// coordinates are aligned so p1 in src and p0 in mask both correspond to r.min in
// the destination.
func (dst *Image) GenDraw(r image.Rectangle, src *Image, p0 image.Point, mask *Image, p1 image.Point) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	draw(dst, r, src, p0, mask, p1, SoverD)
}

// GenDrawOp copies the source image with upper left corner p1 to the destination
// rectangle r, through the specified mask using the specified operation. The
// coordinates are aligned so p1 in src and p0 in mask both correspond to r.min in
// the destination.
func GenDrawOp(dst *Image, r image.Rectangle, src *Image, p0 image.Point, mask *Image, p1 image.Point, op Op) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	draw(dst, r, src, p0, mask, p1, op)
}
