package draw

import (
	"encoding/binary"
	"fmt"
	"image"
	"log"
	"os"
	"strings"
	"sync"

	"9fans.net/go/draw/drawfcall"
)

// Display locking:
// The Exported methods of Display, being entry points for clients, lock the Display structure.
// The unexported ones do not.
// The methods for Font, Image and Screen also lock the associated display by the same rules.

// A Display represents a connection to a display.
type Display struct {
	mu      sync.Mutex // See comment above.
	conn    *drawfcall.Conn
	errch   chan<- error
	bufsize int
	buf     []byte
	imageid uint32
	qmask   *Image
	locking bool

	Image       *Image
	Screen      *Screen
	ScreenImage *Image
	Windows     *Image
	DPI         int // TODO fill in

	White       *Image // Pre-allocated color.
	Black       *Image // Pre-allocated color.
	Opaque      *Image // Pre-allocated color.
	Transparent *Image // Pre-allocated color.

	DefaultFont    *Font
	DefaultSubfont *Subfont
}

// An Image represents an image on the server, possibly visible on the display.
type Image struct {
	Display *Display
	id      uint32
	Pix     Pix             // The pixel format for the image.
	Depth   int             // The depth of the pixels in bits.
	Repl    bool            // Whether the image is replicated (tiles the rectangle).
	R       image.Rectangle // The extent of the image.
	Clipr   image.Rectangle // The clip region.
	next    *Image
	Screen  *Screen // If non-nil, the associated screen; this is a window.
}

// A Screen is a collection of windows that are visible on an image.
type Screen struct {
	Display *Display // Display connected to the server.
	id      uint32
	Fill    *Image // Background image behind the windows.
}

// Refresh algorithms to execute when a window is resized or uncovered.
// Refmesg is almost always the correct one to use.
const (
	Refbackup = 0
	Refnone   = 1
	Refmesg   = 2
)

const deffontname = "*default*"

// Init starts and connects to a server and returns a Display structure through
// which all graphics will be mediated. The arguments are an error channel on
// which to deliver errors (currently unused), the name of the font to use (the
// empty string may be used to represent the default font), the window label,
// and the window size as a string in the form XxY, as in "1000x500"; the units
// are pixels.
// TODO: Use the error channel.
func Init(errch chan<- error, fontname, label, winsize string) (*Display, error) {
	c, err := drawfcall.New()
	if err != nil {
		return nil, err
	}
	d := &Display{
		conn:    c,
		errch:   errch,
		bufsize: 10000,
	}

	// Lock Display so we maintain the contract within this library.
	d.mu.Lock()
	defer d.mu.Unlock()

	d.buf = make([]byte, 0, d.bufsize+5) // 5 for final flush
	if err := c.Init(label, winsize); err != nil {
		c.Close()
		return nil, err
	}

	i, err := d.getimage0(nil)
	if err != nil {
		c.Close()
		return nil, err
	}

	d.Image = i
	d.White, err = d.allocImage(image.Rect(0, 0, 1, 1), GREY1, true, White)
	if err != nil {
		return nil, err
	}
	d.Black, err = d.allocImage(image.Rect(0, 0, 1, 1), GREY1, true, Black)
	if err != nil {
		return nil, err
	}
	d.Opaque = d.White
	d.Transparent = d.Black

	/*
	 * Set up default font
	 */
	df, err := getdefont(d)
	if err != nil {
		return nil, err
	}
	d.DefaultSubfont = df

	if fontname == "" {
		fontname = os.Getenv("font")
	}

	/*
	 * Build fonts with caches==depth of screen, for speed.
	 * If conversion were faster, we'd use 0 and save memory.
	 */
	var font *Font
	if fontname == "" {
		buf := []byte(fmt.Sprintf("%d %d\n0 %d\t%s\n", df.Height, df.Ascent,
			df.N-1, deffontname))
		//fmt.Printf("%q\n", buf)
		//BUG: Need something better for this	installsubfont("*default*", df);
		font, err = d.buildFont(buf, deffontname)
	} else {
		font, err = d.openFont(fontname) // BUG: grey fonts
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "imageinit: can't open default font %s: %v\n", fontname, err)
		return nil, err
	}
	d.DefaultFont = font

	d.Screen, err = i.allocScreen(d.White, false)
	if err != nil {
		return nil, err
	}
	d.ScreenImage = d.Image // temporary, for d.ScreenImage.Pix
	d.ScreenImage, err = allocwindow(nil, d.Screen, i.R, 0, White)
	if err != nil {
		return nil, err
	}
	if err := d.flush(true); err != nil {
		log.Fatal(err)
	}

	screen := d.ScreenImage
	screen.draw(screen.R, d.White, nil, image.ZP)
	if err := d.flush(true); err != nil {
		log.Fatal(err)
	}

	return d, nil
}

func (d *Display) getimage0(i *Image) (*Image, error) {
	if i != nil {
		i.free()
		*i = Image{}
	}

	a := d.bufimage(2)
	a[0] = 'J'
	a[1] = 'I'
	if err := d.flush(false); err != nil {
		fmt.Fprintf(os.Stderr, "cannot read screen info: %v\n", err)
		return nil, err
	}

	info := make([]byte, 12*12)
	n, err := d.conn.ReadDraw(info)
	if err != nil {
		return nil, err
	}
	if n < len(info) {
		return nil, fmt.Errorf("short info from rddraw")
	}

	pix, _ := ParsePix(strings.TrimSpace(string(info[2*12 : 3*12])))
	if i == nil {
		i = new(Image)
	}
	*i = Image{
		Display: d,
		id:      0,
		Pix:     pix,
		Depth:   pix.Depth(),
		Repl:    atoi(info[3*12:]) > 0,
		R:       ator(info[4*12:]),
		Clipr:   ator(info[8*12:]),
	}
	return i, nil
}

// Attach (re-)attaches to a display, typically after a resize, updating the
// display's associated image, screen, and screen image data structures.
func (d *Display) Attach(ref int) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	oi := d.Image
	i, err := d.getimage0(oi)
	if err != nil {
		return err
	}
	d.Image = i
	d.Screen.free()
	d.Screen, err = i.allocScreen(d.White, false)
	if err != nil {
		return err
	}
	d.ScreenImage.free()
	d.ScreenImage, err = allocwindow(d.ScreenImage, d.Screen, i.R, ref, White)
	if err != nil {
		log.Fatal("aw", err)
	}
	return err
}

// Close closes the Display.
func (d *Display) Close() error {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d == nil {
		return nil
	}
	return d.conn.Close()
}

// TODO: drawerror

func (d *Display) flushBuffer() error {
	if len(d.buf) == 0 {
		return nil
	}
	_, err := d.conn.WriteDraw(d.buf)
	d.buf = d.buf[:0]
	if err != nil {
		fmt.Fprintf(os.Stderr, "draw flush: %v\n", err)
		return err
	}
	return nil
}

// Flush flushes pending I/O to the server, making any drawing changes visible.
func (d *Display) Flush() error {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.flush(true)
}

func (d *Display) flush(visible bool) error {
	if visible {
		d.bufsize++
		a := d.bufimage(1)
		d.bufsize--
		a[0] = 'v'
	}

	return d.flushBuffer()
}

func (d *Display) bufimage(n int) []byte {
	if d == nil || n < 0 || n > d.bufsize {
		panic("bad count in bufimage")
	}
	if len(d.buf)+n > d.bufsize {
		if err := d.flushBuffer(); err != nil {
			panic("bufimage flush: " + err.Error())
		}
	}
	i := len(d.buf)
	d.buf = d.buf[:i+n]
	return d.buf[i:]
}

const DefaultDPI = 133

// TODO: Document.
func (d *Display) Scale(n int) int {
	if d == nil || d.DPI <= DefaultDPI {
		return n
	}
	return (n*d.DPI + DefaultDPI/2) / DefaultDPI
}

func atoi(b []byte) int {
	i := 0
	for i < len(b) && b[i] == ' ' {
		i++
	}
	n := 0
	for ; i < len(b) && '0' <= b[i] && b[i] <= '9'; i++ {
		n = n*10 + int(b[i]) - '0'
	}
	return n
}

func atop(b []byte) image.Point {
	return image.Pt(atoi(b), atoi(b[12:]))
}

func ator(b []byte) image.Rectangle {
	return image.Rectangle{atop(b), atop(b[2*12:])}
}

func bplong(b []byte, n uint32) {
	binary.LittleEndian.PutUint32(b, n)
}

func bpshort(b []byte, n uint16) {
	binary.LittleEndian.PutUint16(b, n)
}
