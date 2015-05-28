package drawfcall

import (
	"fmt"
	"image"
	"io"
)

const (
	_ = iota
	Rerror
	Trdmouse
	Rrdmouse
	Tmoveto
	Rmoveto
	Tcursor
	Rcursor
	Tbouncemouse
	Rbouncemouse
	Trdkbd
	Rrdkbd
	Tlabel
	Rlabel
	Tinit
	Rinit
	Trdsnarf
	Rrdsnarf
	Twrsnarf
	Rwrsnarf
	Trddraw
	Rrddraw
	Twrdraw
	Rwrdraw
	Ttop
	Rtop
	Tresize
	Rresize
	Tmax
)

const MAXMSG = 4 << 20

type Msg struct {
	Type    uint8
	Tag     uint8
	Mouse   Mouse
	Resized bool
	Cursor  Cursor
	Arrow   bool
	Rune    rune
	Winsize string
	Label   string
	Snarf   []byte
	Error   string
	Data    []byte
	Count   int
	Rect    image.Rectangle
}

type Mouse struct {
	image.Point
	Buttons int
	Msec    int
}

type Cursor struct {
	image.Point
	Clr [32]byte
	Set [32]byte
}

func stringsize(s string) int {
	return 4 + len(s)
}

func bytesize(b []byte) int {
	return 4 + len(b)
}

func (m *Msg) Size() int {
	switch m.Type {
	case Trdmouse,
		Rbouncemouse,
		Rmoveto,
		Rcursor,
		Trdkbd,
		Rlabel,
		Rinit,
		Trdsnarf,
		Rwrsnarf,
		Ttop,
		Rtop,
		Rresize:
		return 4 + 1 + 1
	case Rrdmouse:
		return 4 + 1 + 1 + 4 + 4 + 4 + 4 + 1
	case Tbouncemouse:
		return 4 + 1 + 1 + 4 + 4 + 4
	case Tmoveto:
		return 4 + 1 + 1 + 4 + 4
	case Tcursor:
		return 4 + 1 + 1 + 4 + 4 + 2*16 + 2*16 + 1
	case Rerror:
		return 4 + 1 + 1 + stringsize(m.Error)
	case Rrdkbd:
		return 4 + 1 + 1 + 2
	case Tlabel:
		return 4 + 1 + 1 + stringsize(m.Label)
	case Tinit:
		return 4 + 1 + 1 + stringsize(m.Winsize) + stringsize(m.Label)
	case Rrdsnarf,
		Twrsnarf:
		return 4 + 1 + 1 + bytesize(m.Snarf)
	case Rrddraw,
		Twrdraw:
		return 4 + 1 + 1 + bytesize(m.Data)
	case Trddraw,
		Rwrdraw:
		return 4 + 1 + 1 + 4
	case Tresize:
		return 4 + 1 + 1 + 4*4
	}
	return 0
}

func (m *Msg) Marshal() []byte {
	n := m.Size()
	if n < 6 {
		return nil
	}
	b := make([]byte, 0, n)
	b = pbit32(b, n)
	b = pbit8(b, m.Tag)
	b = pbit8(b, m.Type)

	switch m.Type {
	case Rerror:
		b = pstring(b, m.Error)
	case Rrdmouse:
		b = pbit32(b, m.Mouse.X)
		b = pbit32(b, m.Mouse.Y)
		b = pbit32(b, m.Mouse.Buttons)
		b = pbit32(b, m.Mouse.Msec)
		b = append(b, boolbyte(m.Resized))
		b[19], b[22] = b[22], b[19]
	case Tbouncemouse:
		b = pbit32(b, m.Mouse.X)
		b = pbit32(b, m.Mouse.Y)
		b = pbit32(b, m.Mouse.Buttons)
	case Tmoveto:
		b = pbit32(b, m.Mouse.X)
		b = pbit32(b, m.Mouse.Y)
	case Tcursor:
		b = pbit32(b, m.Cursor.X)
		b = pbit32(b, m.Cursor.Y)
		b = append(b, m.Cursor.Clr[:]...)
		b = append(b, m.Cursor.Set[:]...)
		b = append(b, boolbyte(m.Arrow))
	case Rrdkbd:
		b = pbit16(b, uint16(m.Rune))
	case Tlabel:
		b = pstring(b, m.Label)
	case Tinit:
		b = pstring(b, m.Winsize)
		b = pstring(b, m.Label)
	case Rrdsnarf, Twrsnarf:
		b = pbytes(b, m.Snarf)
	case Rrddraw, Twrdraw:
		b = pbit32(b, len(m.Data))
		b = append(b, m.Data...)
	case Trddraw, Rwrdraw:
		b = pbit32(b, m.Count)
	case Tresize:
		b = pbit32(b, m.Rect.Min.X)
		b = pbit32(b, m.Rect.Min.Y)
		b = pbit32(b, m.Rect.Max.X)
		b = pbit32(b, m.Rect.Max.Y)
	}
	if len(b) != n {
		println(len(b), n, m.String())
		panic("size mismatch")
	}
	return b
}

func boolbyte(b bool) byte {
	if b {
		return 1
	}
	return 0
}

func ReadMsg(r io.Reader) ([]byte, error) {
	size := make([]byte, 4)
	_, err := io.ReadFull(r, size)
	if err != nil {
		return nil, err
	}
	n, _ := gbit32(size[:])
	buf := make([]byte, n)
	copy(buf, size)
	_, err = io.ReadFull(r, buf[4:])
	if err != nil {
		if err == io.EOF {
			err = io.ErrUnexpectedEOF
		}
		return nil, err
	}
	return buf, nil
}

func (m *Msg) Unmarshal(b []byte) error {
	if len(b) < 6 {
		return fmt.Errorf("short packet")
	}

	nn, b := gbit32(b)
	if nn != 4+len(b) {
		return fmt.Errorf("invalid size")
	}

	m.Tag, b = gbit8(b)
	m.Type, b = gbit8(b)
	switch m.Type {
	default:
		return fmt.Errorf("invalid type")
	case Trdmouse,
		Rbouncemouse,
		Rmoveto,
		Rcursor,
		Trdkbd,
		Rlabel,
		Rinit,
		Trdsnarf,
		Rwrsnarf,
		Ttop,
		Rtop,
		Rresize:
		// nothing
	case Rerror:
		m.Error, b = gstring(b)
	case Rrdmouse:
		m.Mouse.X, b = gbit32(b)
		m.Mouse.Y, b = gbit32(b)
		m.Mouse.Buttons, b = gbit32(b)
		b[1], b[4] = b[4], b[1]
		m.Mouse.Msec, b = gbit32(b)
		m.Resized = b[0] != 0
		b = b[1:]
	case Tbouncemouse:
		m.Mouse.X, b = gbit32(b)
		m.Mouse.Y, b = gbit32(b)
		m.Mouse.Buttons, b = gbit32(b)
	case Tmoveto:
		m.Mouse.X, b = gbit32(b)
		m.Mouse.Y, b = gbit32(b)
	case Tcursor:
		m.Cursor.X, b = gbit32(b)
		m.Cursor.Y, b = gbit32(b)
		copy(m.Cursor.Clr[:], b[:])
		copy(m.Cursor.Set[:], b[32:])
		b = b[64:]
		var n byte
		n, b = gbit8(b)
		m.Arrow = n != 0
	case Rrdkbd:
		var r uint16
		r, b = gbit16(b)
		m.Rune = rune(r)
	case Tlabel:
		m.Label, b = gstring(b)
	case Tinit:
		m.Winsize, b = gstring(b)
		m.Label, b = gstring(b)
	case Rrdsnarf,
		Twrsnarf:
		m.Snarf, b = gbytes(b)
	case Rrddraw,
		Twrdraw:
		var n int
		n, b = gbit32(b)
		m.Data = b[:n]
		b = b[n:]
	case Trddraw,
		Rwrdraw:
		m.Count, b = gbit32(b)
	case Tresize:
		m.Rect.Min.X, b = gbit32(b)
		m.Rect.Min.Y, b = gbit32(b)
		m.Rect.Max.X, b = gbit32(b)
		m.Rect.Max.Y, b = gbit32(b)
	}

	if len(b) != 0 {
		return fmt.Errorf("junk at end of packet %d %s", len(b), m)
	}
	return nil
}

func (m *Msg) String() string {
	s := fmt.Sprintf("tag=%d ", m.Tag)
	switch m.Type {
	default:
		s += fmt.Sprintf("unknown msg type=%d", m.Type)
	case Rerror:
		s += fmt.Sprintf("Rerror error='%s'", m.Error)
	case Trdmouse:
		s += fmt.Sprintf("Trdmouse")
	case Rrdmouse:
		s += fmt.Sprintf("Rrdmouse x=%d y=%d buttons=%d msec=%d resized=%v",
			m.Mouse.X, m.Mouse.Y,
			m.Mouse.Buttons, m.Mouse.Msec, m.Resized)
	case Tbouncemouse:
		s += fmt.Sprintf("Tbouncemouse x=%d y=%d buttons=%d",
			m.Mouse.X, m.Mouse.Y, m.Mouse.Buttons)
	case Rbouncemouse:
		s += fmt.Sprintf("Rbouncemouse")
	case Tmoveto:
		s += fmt.Sprintf("Tmoveto x=%d y=%d", m.Mouse.X, m.Mouse.Y)
	case Rmoveto:
		s += fmt.Sprintf("Rmoveto")
	case Tcursor:
		s += fmt.Sprintf("Tcursor arrow=%v", m.Arrow)
	case Rcursor:
		s += fmt.Sprintf("Rcursor")
	case Trdkbd:
		s += fmt.Sprintf("Trdkbd")
	case Rrdkbd:
		s += fmt.Sprintf("Rrdkbd rune=%c", m.Rune)
	case Tlabel:
		s += fmt.Sprintf("Tlabel label='%s'", m.Label)
	case Rlabel:
		s += fmt.Sprintf("Rlabel")
	case Tinit:
		s += fmt.Sprintf("Tinit label='%s' winsize='%s'", m.Label, m.Winsize)
	case Rinit:
		s += fmt.Sprintf("Rinit")
	case Trdsnarf:
		s += fmt.Sprintf("Trdsnarf")
	case Rrdsnarf:
		s += fmt.Sprintf("Rrdsnarf snarf='%s'", m.Snarf)
	case Twrsnarf:
		s += fmt.Sprintf("Twrsnarf snarf='%s'", m.Snarf)
	case Rwrsnarf:
		s += fmt.Sprintf("Rwrsnarf")
	case Trddraw:
		s += fmt.Sprintf("Trddraw %d", m.Count)
	case Rrddraw:
		s += fmt.Sprintf("Rrddraw %d %x", len(m.Data), m.Data)
	case Twrdraw:
		s += fmt.Sprintf("Twrdraw %d %x", len(m.Data), m.Data)
	case Rwrdraw:
		s += fmt.Sprintf("Rwrdraw %d", m.Count)
	case Ttop:
		s += fmt.Sprintf("Ttop")
	case Rtop:
		s += fmt.Sprintf("Rtop")
	case Tresize:
		s += fmt.Sprintf("Tresize %v", m.Rect)
	case Rresize:
		s += fmt.Sprintf("Rresize")
	}
	return s
}
