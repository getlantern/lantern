package draw

import (
	"fmt"
	"image"
	"log"
	"os"
)

// Mouse is the structure describing the current state of the mouse.
type Mouse struct {
	image.Point        // Location.
	Buttons     int    // Buttons; bit 0 is button 1, bit 1 is button 2, etc.
	Msec        uint32 // Time stamp in milliseconds.
}

// TODO: Mouse field is racy but okay.

// Mousectl holds the interface to receive mouse events.
// The Mousectl's Mouse is updated after send so it doesn't
// have the wrong value if the sending goroutine blocks during send.
// This means that programs should receive into Mousectl.Mouse
//  if they want full synchrony.
type Mousectl struct {
	Mouse                // Store Mouse events here.
	C       <-chan Mouse // Channel of Mouse events.
	Resize  <-chan bool  // Each received value signals a window resize (see the display.Attach method).
	Display *Display     // The associated display.
}

// InitMouse connects to the mouse and returns a Mousectl to interact with it.
func (d *Display) InitMouse() *Mousectl {
	ch := make(chan Mouse, 0)
	rch := make(chan bool, 2)
	mc := &Mousectl{
		C:       ch,
		Resize:  rch,
		Display: d,
	}
	go mouseproc(mc, d, ch, rch)
	return mc
}

func mouseproc(mc *Mousectl, d *Display, ch chan Mouse, rch chan bool) {
	for {
		m, resized, err := d.conn.ReadMouse()
		if err != nil {
			log.Fatal(err)
		}
		if resized {
			rch <- true
		}
		mm := Mouse{image.Point{m.X, m.Y}, m.Buttons, uint32(m.Msec)}
		ch <- mm
		/*
		 * See comment above.
		 */
		mc.Mouse = mm
	}
}

// Read returns the next mouse event.
func (mc *Mousectl) Read() Mouse {
	mc.Display.Flush()
	m := <-mc.C
	mc.Mouse = m
	return m
}

// Moveto moves the mouse cursor to the specified location.
func (d *Display) MoveTo(pt image.Point) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	err := d.conn.MoveTo(pt)
	if err != nil {
		fmt.Fprintf(os.Stderr, "MoveTo: %v\n", err)
		return err
	}
	return nil
}
