package drawfcall

import (
	"fmt"
	"image"
	"io"
	"os"
	"os/exec"
	"sync"
)

type Conn struct {
	r  sync.Mutex
	rd io.ReadCloser

	w  sync.Mutex
	wr io.WriteCloser

	tag     sync.Mutex
	muxer   bool
	freetag map[byte]bool
	tagmap  map[byte]chan []byte
}

func New() (*Conn, error) {
	devdraw := os.Getenv("DEVDRAW")
	r1, w1, _ := os.Pipe()
	r2, w2, _ := os.Pipe()
	if devdraw == "" {
		devdraw = "devdraw"
	}
	cmd := exec.Command(devdraw, os.Args[0], "(devdraw)")
	cmd.Args[0] = os.Args[0]
	cmd.Env = []string{"NOLIBTHREADDAEMONIZE=1"}
	cmd.Env = append(cmd.Env, os.Environ()...)
	cmd.Dir = "/"
	cmd.Stdin = r1
	cmd.Stdout = w2
	cmd.Stderr = os.Stderr
	err := cmd.Start()
	r1.Close()
	w2.Close()
	if err != nil {
		r2.Close()
		w1.Close()
		return nil, fmt.Errorf("drawfcall.New: %v", err)
	}

	c := &Conn{
		rd:      r2,
		wr:      w1,
		freetag: make(map[byte]bool),
		tagmap:  make(map[byte]chan []byte),
	}
	for i := 1; i <= 254; i++ {
		c.freetag[byte(i)] = true
	}
	c.rd = r2
	c.wr = w1
	return c, nil
}

func (c *Conn) RPC(tx, rx *Msg) error {
	msg := tx.Marshal()
	ch := make(chan []byte, 1)
	c.tag.Lock()
	if len(c.freetag) == 0 {
		c.tag.Unlock()
		return fmt.Errorf("out of tags")
	}
	var tag byte
	for tag = range c.freetag {
		break
	}
	delete(c.freetag, tag)
	c.tagmap[tag] = ch
	if !c.muxer {
		c.muxer = true
		ch <- nil
	}
	c.tag.Unlock()
	c.w.Lock()
	msg[4] = tag
	_, err := c.wr.Write(msg)
	c.w.Unlock()
	if err != nil {
		return err
	}
	for msg = range ch {
		if msg != nil {
			break
		}
		msg, err = ReadMsg(c.rd)
		if err != nil {
			return err
		}
		c.tag.Lock()
		tag := msg[4]
		ch1 := c.tagmap[tag]
		delete(c.tagmap, tag)
		c.freetag[tag] = true
		c.muxer = false
		for _, ch2 := range c.tagmap {
			c.muxer = true
			ch2 <- nil
			break
		}
		c.tag.Unlock()
		ch1 <- msg
	}
	if err := rx.Unmarshal(msg); err != nil {
		return err
	}
	if rx.Type == Rerror {
		return fmt.Errorf("%s", rx.Error)
	}
	if rx.Type != tx.Type+1 {
		return fmt.Errorf("type mismatch")
	}
	return nil
}

func (c *Conn) Close() error {
	c.w.Lock()
	err1 := c.wr.Close()
	c.w.Unlock()
	c.r.Lock()
	err2 := c.rd.Close()
	c.r.Unlock()
	if err1 != nil {
		return err1
	}
	return err2
}

func (c *Conn) Init(label, winsize string) error {
	tx := &Msg{Type: Tinit, Label: label, Winsize: winsize}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) ReadMouse() (m Mouse, resized bool, err error) {
	tx := &Msg{Type: Trdmouse}
	rx := &Msg{}
	if err = c.RPC(tx, rx); err != nil {
		return
	}
	m = rx.Mouse
	resized = rx.Resized
	return
}

func (c *Conn) ReadKbd() (r rune, err error) {
	tx := &Msg{Type: Trdkbd}
	rx := &Msg{}
	if err = c.RPC(tx, rx); err != nil {
		return
	}
	r = rx.Rune
	return
}

func (c *Conn) MoveTo(p image.Point) error {
	tx := &Msg{Type: Tmoveto, Mouse: Mouse{Point: p}}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) Cursor(cursor *Cursor) error {
	tx := &Msg{Type: Tcursor}
	if cursor == nil {
		tx.Arrow = true
	} else {
		tx.Cursor = *cursor
	}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) BounceMouse(m *Mouse) error {
	tx := &Msg{Type: Tbouncemouse, Mouse: *m}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) Label(label string) error {
	tx := &Msg{Type: Tlabel, Label: label}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

// Return values are bytes copied, actual size, error.
func (c *Conn) ReadSnarf(b []byte) (int, int, error) {
	tx := &Msg{Type: Trdsnarf}
	rx := &Msg{}
	if err := c.RPC(tx, rx); err != nil {
		return 0, 0, err
	}
	n := copy(b, rx.Snarf)
	if n < len(rx.Snarf) {
		return 0, len(rx.Snarf), nil
	}
	return n, n, nil
}

func (c *Conn) WriteSnarf(snarf []byte) error {
	tx := &Msg{Type: Twrsnarf, Snarf: snarf}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) Top() error {
	tx := &Msg{Type: Ttop}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) Resize(r image.Rectangle) error {
	tx := &Msg{Type: Tresize, Rect: r}
	rx := &Msg{}
	return c.RPC(tx, rx)
}

func (c *Conn) ReadDraw(b []byte) (int, error) {
	tx := &Msg{Type: Trddraw, Count: len(b)}
	rx := &Msg{}
	if err := c.RPC(tx, rx); err != nil {
		return 0, err
	}
	copy(b, rx.Data)
	return len(rx.Data), nil
}

func (c *Conn) WriteDraw(b []byte) (int, error) {
	tx := &Msg{Type: Twrdraw, Data: b}
	rx := &Msg{}
	if err := c.RPC(tx, rx); err != nil {
		return 0, err
	}
	return rx.Count, nil
}
