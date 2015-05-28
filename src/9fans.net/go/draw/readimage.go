package draw

import (
	"fmt"
	"image"
	"io"
	"strings"
)

// ReadImage reads the image data from the reader and returns the image it describes.
func (d *Display) ReadImage(r io.Reader) (*Image, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.readImage(r)
}

func (d *Display) readImage(rd io.Reader) (*Image, error) {
	fd := rd
	hdr := make([]byte, 5*12)

	_, err := io.ReadFull(fd, hdr[:11])
	if err != nil {
		return nil, fmt.Errorf("reading image header: %v", err)
	}
	if string(hdr[:11]) == "compressed\n" {
		return d.creadimage(rd)
	}

	_, err = io.ReadFull(fd, hdr[11:])
	if err != nil {
		return nil, fmt.Errorf("reading image header: %v", err)
	}

	chunk := 8192
	if d != nil {
		chunk = d.bufsize - 32 // a little room for header
	}

	/*
	 * distinguish new channel descriptor from old ldepth.
	 * channel descriptors have letters as well as numbers,
	 * while ldepths are a single digit formatted as %-11d.
	 */
	new := false
	for m := 0; m < 10; m++ {
		if hdr[m] != ' ' {
			new = true
			break
		}
	}
	if hdr[11] != ' ' {
		return nil, fmt.Errorf("readimage: bad format")
	}
	var pix Pix
	if new {
		pix, err = ParsePix(strings.TrimSpace(string(hdr[:12])))
		if err != nil {
			return nil, fmt.Errorf("readimage: %v", err)
		}
	} else {
		ldepth := int(hdr[10]) - '0'
		if ldepth < 0 || ldepth > 3 {
			return nil, fmt.Errorf("readimage: bad ldepth %d", ldepth)
		}
		pix = ldepthToPix[ldepth]
	}
	r := ator(hdr[1*12:])
	if r.Min.X > r.Max.X || r.Min.Y > r.Max.Y {
		return nil, fmt.Errorf("readimage: bad rectangle")
	}

	miny := r.Min.Y
	maxy := r.Max.Y

	l := BytesPerLine(r, pix.Depth())
	var i *Image
	if d != nil {
		i, err = d.allocImage(r, pix, false, 0)
		if err != nil {
			return nil, err
		}
	} else {
		i = &Image{R: r, Pix: pix, Depth: pix.Depth()}
	}

	tmp := make([]byte, chunk)
	if tmp == nil {
		goto Err
	}
	for maxy > miny {
		dy := maxy - miny
		if dy*l > chunk {
			dy = chunk / l
		}
		if dy <= 0 {
			err = fmt.Errorf("readimage: image too wide for buffer")
			goto Err
		}
		n := dy * l
		if _, err = io.ReadFull(fd, tmp[:n]); err != nil {
			goto Err
		}
		if !new { /* an old image: must flip all the bits */
			for i, b := range tmp[:n] {
				_, _ = i, b //	tmp[i] = b ^ 0xFF
			}
		}
		if d != nil {
			if _, err = i.load(image.Rect(r.Min.X, miny, r.Max.X, miny+dy), tmp[:n]); err != nil {
				goto Err
			}
		}
		miny += dy
	}
	return i, nil

Err:
	if d != nil {
		i.free()
	}
	return nil, err
}
