package draw

import (
	"fmt"
	"image"
	"runtime"
)

// AllocImage allocates a new Image on display d. The arguments are:
// - the rectangle representing the size
// - the pixel descriptor: RGBA32 etc.
// - whether the image is to be replicated (tiled)
// - the starting background color for the image
func (d *Display) AllocImage(r image.Rectangle, pix Pix, repl bool, val Color) (*Image, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return allocImage(d, nil, r, pix, repl, val, 0, 0)
}

func (d *Display) allocImage(r image.Rectangle, pix Pix, repl bool, val Color) (i *Image, err error) {
	return allocImage(d, nil, r, pix, repl, val, 0, 0)
}

func allocImage(d *Display, ai *Image, r image.Rectangle, pix Pix, repl bool, val Color, screenid uint32, refresh int) (i *Image, err error) {
	defer func() {
		if err != nil {
			err = fmt.Errorf("allocimage %v %v: %v", r, pix, err)
			i.free()
			i = nil
		}
	}()

	depth := pix.Depth()
	if depth == 0 {
		err = fmt.Errorf("bad channel descriptor")
		return
	}

	// flush pending data so we don't get error allocating the image
	d.flush(false)
	a := d.bufimage(1 + 4 + 4 + 1 + 4 + 1 + 4*4 + 4*4 + 4)
	d.imageid++
	id := d.imageid
	a[0] = 'b'
	bplong(a[1:], id)
	bplong(a[5:], screenid)
	a[9] = byte(refresh)
	bplong(a[10:], uint32(pix))
	if repl {
		a[14] = 1
	} else {
		a[14] = 0
	}
	bplong(a[15:], uint32(r.Min.X))
	bplong(a[19:], uint32(r.Min.Y))
	bplong(a[23:], uint32(r.Max.X))
	bplong(a[27:], uint32(r.Max.Y))
	clipr := r
	if repl {
		// huge but not infinite, so various offsets will leave it huge, not overflow
		clipr = image.Rect(-0x3FFFFFFF, -0x3FFFFFFF, 0x3FFFFFFF, 0x3FFFFFFF)
	}
	bplong(a[31:], uint32(clipr.Min.X))
	bplong(a[35:], uint32(clipr.Min.Y))
	bplong(a[39:], uint32(clipr.Max.X))
	bplong(a[43:], uint32(clipr.Max.Y))
	bplong(a[47:], uint32(val))
	if err = d.flush(false); err != nil {
		return
	}

	i = ai
	if i == nil {
		i = new(Image)
	}
	*i = Image{
		Display: d,
		id:      id,
		Pix:     pix,
		Depth:   pix.Depth(),
		R:       r,
		Clipr:   clipr,
		Repl:    repl,
	}
	runtime.SetFinalizer(i, (*Image).Free)
	return i, nil
}

/*
func namedimage(d *Display, name string) (*Image, nil) {
	panic("namedimage")
}

func nameimage(i *Image, name string, in bool) error {
	a := i.Display.bufimage(1+4+1+1+len(name))
	a[0] = 'N'
	bplong(a[1:], i.ID)
	if in {
		a[5] = 1
	}
	a[6] = len(name)
	copy(a[7:], name)
	return d.flushimage(false)
}
*/

func (i *Image) free() error {
	if i == nil || i.Display == nil {
		return nil
	}
	// make sure no refresh events occur on this if we block in the write
	d := i.Display
	// flush pending data so we don't get error deleting the image
	d.flush(false)
	a := d.bufimage(1 + 4)
	a[0] = 'f'
	bplong(a[1:], i.id)
	if i.Screen != nil {
		w := d.Windows
		if w == i {
			d.Windows = i.next
		} else {
			for ; w != nil; w = w.next {
				if w.next == i {
					w.next = i.next
					break
				}
			}
		}
	}
	i.Display = nil // So a second free (perhaps through a Finalizer) will be OK.
	runtime.SetFinalizer(i, nil)
	return d.flush(i.Screen != nil)
}

// Free frees the server resources for the image. Images have a finalizer that
// calls Free automatically, if necessary, for garbage collected Images, but it
// is more efficient to be explicit.
func (i *Image) Free() error {
	if i == nil {
		return nil
	}
	if i.Display != nil && i == i.Display.ScreenImage {
		panic("freeimage of ScreenImage")
	}
	i.Display.mu.Lock()
	defer i.Display.mu.Unlock()
	return i.free()
}
