package draw

import (
	"fmt"
	"io"
)

func (d *Display) readSubfont(name string, fd io.Reader, ai *Image) (*Subfont, error) {
	hdr := make([]byte, 3*12+4)
	i := ai
	if i == nil {
		var err error
		i, err = d.readImage(fd)
		if err != nil {
			return nil, err
		}
	}
	var (
		n   int
		p   []byte
		fc  []Fontchar
		f   *Subfont
		err error
	)
	// Release lock for the I/O - could take a long time.
	if d != nil {
		d.mu.Unlock()
	}
	_, err = io.ReadFull(fd, hdr[:3*12])
	if d != nil {
		d.mu.Lock()
	}
	if err != nil {
		err = fmt.Errorf("rdsubfontfile: header read error: %v", err)
		goto Err
	}
	n = atoi(hdr)
	p = make([]byte, 6*(n+1))
	if _, err = io.ReadFull(fd, p); err != nil {
		err = fmt.Errorf("rdsubfontfile: fontchar read error: %v", err)
		goto Err
	}
	fc = make([]Fontchar, n+1)
	unpackinfo(fc, p, n)
	f = d.allocSubfont(name, atoi(hdr[12:]), atoi(hdr[24:]), fc, i)
	return f, nil

Err:
	if ai == nil {
		i.free()
	}
	return nil, err
}

// ReadSubfont reads the subfont data from the reader and returns the subfont
// it describes, giving it the specified name.
func (d *Display) ReadSubfont(name string, r io.Reader) (*Subfont, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.readSubfont(name, r, nil)
}

func unpackinfo(fc []Fontchar, p []byte, n int) {
	for j := 0; j <= n; j++ {
		fc[j].X = int(p[0]) | int(p[1])<<8
		fc[j].Top = uint8(p[2])
		fc[j].Bottom = uint8(p[3])
		fc[j].Left = int8(p[4])
		fc[j].Width = uint8(p[5])
		p = p[6:]
	}
}
