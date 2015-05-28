package draw

import (
	"fmt"
	"io"
	"strings"
)

var ldepthToPix = []Pix{
	GREY1,
	GREY2,
	GREY4,
	CMAP8,
}

func (d *Display) creadimage(rd io.Reader) (*Image, error) {
	fd := rd
	hdr := make([]byte, 5*12)

	_, err := io.ReadFull(fd, hdr)
	if err != nil {
		return nil, fmt.Errorf("reading image header: %v", err)
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
		return nil, fmt.Errorf("creadimage: bad format")
	}
	var pix Pix
	if new {
		pix, err = ParsePix(strings.TrimSpace(string(hdr[:12])))
		if err != nil {
			return nil, fmt.Errorf("creadimage: %v", err)
		}
	} else {
		ldepth := int(hdr[10]) - '0'
		if ldepth < 0 || ldepth > 3 {
			return nil, fmt.Errorf("creadimage: bad ldepth %d", ldepth)
		}
		pix = ldepthToPix[ldepth]
	}
	r := ator(hdr[1*12:])
	if r.Min.X > r.Max.X || r.Min.Y > r.Max.Y {
		return nil, fmt.Errorf("creadimage: bad rectangle")
	}

	var i *Image
	if d != nil {
		i, err = d.allocImage(r, pix, false, 0)
		if err != nil {
			return nil, err
		}
	} else {
		i = &Image{R: r, Pix: pix, Depth: pix.Depth()}
	}

	ncblock := compblocksize(r, pix.Depth())
	buf := make([]byte, ncblock)
	miny := r.Min.Y
	for miny != r.Max.Y {
		if _, err = io.ReadFull(fd, hdr[:2*12]); err != nil {
			goto Errout
		}
		maxy := atoi(hdr[0*12:])
		nb := atoi(hdr[1*12:])
		if maxy <= miny || r.Max.Y < maxy {
			err = fmt.Errorf("creadimage: bad maxy %d", maxy)
			goto Errout
		}
		if nb <= 0 || ncblock < nb {
			err = fmt.Errorf("creadimage: bad count %d", nb)
			goto Errout
		}
		if _, err = io.ReadFull(fd, buf[:nb]); err != nil {
			goto Errout
		}
		if d != nil {
			a := d.bufimage(21 + nb)
			// XXX err
			if err != nil {
				goto Errout
			}
			a[0] = 'Y'
			bplong(a[1:], i.id)
			bplong(a[5:], uint32(r.Min.X))
			bplong(a[9:], uint32(miny))
			bplong(a[13:], uint32(r.Max.X))
			bplong(a[17:], uint32(maxy))
			if !new { // old image: flip the data bits
				twiddlecompressed(buf[:nb])
			}
			copy(a[21:], buf)
		}
		miny = maxy
	}
	return i, nil

Errout:
	if d != nil {
		i.free()
	}
	return nil, err
}
