package draw

import (
	"fmt"
	"image"
)

// Load copies the pixel data from the buffer to the specified rectangle of the image.
// The buffer must be big enough to fill the rectangle.
func (dst *Image) Load(r image.Rectangle, data []byte) (int, error) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	return dst.load(r, data)
}

func (dst *Image) load(r image.Rectangle, data []byte) (int, error) {
	i := dst
	chunk := i.Display.bufsize - 64
	if !r.In(i.R) {
		return 0, fmt.Errorf("loadimage: bad rectangle")
	}
	bpl := BytesPerLine(r, i.Depth)
	n := bpl * r.Dy()
	if n > len(data) {
		return 0, fmt.Errorf("loadimage: insufficient data")
	}
	ndata := 0
	for r.Max.Y > r.Min.Y {
		dy := r.Max.Y - r.Min.Y
		if dy*bpl > chunk {
			dy = chunk / bpl
		}
		if dy <= 0 {
			return 0, fmt.Errorf("loadimage: image too wide for buffer")
		}
		n := dy * bpl
		a := i.Display.bufimage(21 + n)
		a[0] = 'y'
		bplong(a[1:], uint32(i.id))
		bplong(a[5:], uint32(r.Min.X))
		bplong(a[9:], uint32(r.Min.Y))
		bplong(a[13:], uint32(r.Max.X))
		bplong(a[17:], uint32(r.Min.Y+dy))
		copy(a[21:], data)
		ndata += n
		data = data[n:]
		r.Min.Y += dy
	}
	if err := i.Display.flush(false); err != nil {
		return ndata, err
	}
	return ndata, nil
}
