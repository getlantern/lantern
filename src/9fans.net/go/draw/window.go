package draw

import (
	"fmt"
	"image"
)

var screenid uint32

func (i *Image) AllocScreen(fill *Image, public bool) (*Screen, error) {
	i.Display.mu.Lock()
	defer i.Display.mu.Unlock()
	return i.allocScreen(fill, public)
}

func (i *Image) allocScreen(fill *Image, public bool) (*Screen, error) {
	d := i.Display
	if d != fill.Display {
		return nil, fmt.Errorf("allocscreen: image and fill on different displays")
	}
	var id uint32
	for try := 0; ; try++ {
		if try >= 25 {
			return nil, fmt.Errorf("allocscreen: cannot find free id")
		}
		a := d.bufimage(1 + 4 + 4 + 4 + 1)
		screenid++
		id = screenid
		a[0] = 'A'
		bplong(a[1:], id)
		bplong(a[5:], i.id)
		bplong(a[9:], fill.id)
		if public {
			a[13] = 1
		}
		if err := d.flush(false); err == nil {
			break
		}
	}
	s := &Screen{
		Display: d,
		id:      id,
		Fill:    fill,
	}
	return s, nil
}

/*
func publicscreen(d *Display, id, pix uint32) (*Screen, error) {
	s := new(Screen)
	a := d.bufimage(1+4+4)
	a[0] = 'S'
	bplong(a[1:], id)
	bplong(a[5:], pix)
	if err := d.flushimage(false); err != nil {
		return nil, err
	}
	s.Display = d
	s.id = id
	return s
}
*/

// Free frees the server resources associated with the screen.
func (s *Screen) Free() error {
	s.Display.mu.Lock()
	defer s.Display.mu.Unlock()
	return s.free()
}

func (s *Screen) free() error {
	if s == nil {
		return nil
	}
	d := s.Display
	a := d.bufimage(1 + 4)
	a[0] = 'F'
	bplong(a[1:], s.id)
	// flush(true) because screen is likely holding the last reference to window,
	// and we want it to disappear visually.
	return d.flush(true)
}

func allocwindow(i *Image, s *Screen, r image.Rectangle, ref int, val Color) (*Image, error) {
	d := s.Display
	i, err := allocImage(d, i, r, d.ScreenImage.Pix, false, val, s.id, ref)
	if err != nil {
		return nil, err
	}
	i.Screen = s
	i.next = s.Display.Windows
	s.Display.Windows = i
	return i, nil
}

/*
func topbottom(w []*Image, top bool) {
	if n == 0 {
		return
	}
	if n < 0 || n > (w[0].Display.bufsize-100)/4 {
		fmt.Fprint(os.Stderr, "top/bottom: ridiculous number of windows\n")
		return
	}

	/*
	 * this used to check that all images were on the same screen.
	 * we don't know the screen associated with images we acquired
	 * by name.  instead, check that all images are on the same display.
	 * the display will check that they are all on the same screen.
	 * /
	d := w[0].Display
	for i := 1; i < n; i++ {
		if w[i].Display != d {
			fmt.Fprint(os.Stderr, "top/bottom: windows not on same screen\n");
			return
		}
	}

	b := d.bufimage(1+1+2+4*n);
	b[0] = 't';
	if top {
		b[1] = 1
	}
	bpshort(b[2:], n)
	for i:=0; i<n; i++ {
		bplong(b[4+4*i:], w[i].id);
	}
}

func bottomwindow(w *Image) {
	if w.Screen == nil {
		return
	}
	topbottom([]*Image{w}, false)
}

func topwindow(w *Image) {
	if w.Screen == nil {
		return
	}
	topbottom([]*Image{w}, true)
}

func bottomnwindows(w []*Image) {
	topbottom(w, false)
}

func topnwindows(w []*Image) {
	topbottom(w, true)
}

func originwindow(w *Image, log, scr image.Point) error {
	w.Display.flushimage(false)
	b := w.Display.bufimage(1+4+2*4+2*4)
	b[0] = 'o'
	bplong(b[1:], w.id)
	bplong(b[5:], uint32(log.X))
	bplong(b[9:], uint32(log.Y))
	bplong(b[13:], uint32(scr.X))
	bplong(b[17:], uint32(scr.Y))
	if err := w.Display.flushimage(true); err != nil {
		return err
	}
	delta := log.Sub(w.R.Min)
	w.R = w.R.Add(delta)
	w.Clipr = w.Clipr.Add(delta)
	return nil
}
*/
