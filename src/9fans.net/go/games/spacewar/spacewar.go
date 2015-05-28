// Copyright (c) 1996 Barry Silverman, Brian Silverman, Vadim Gerasimov.
// Portions Copyright (c) 2009 The Go Authors.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

package main // import "9fans.net/go/games/spacewar"

import (
	"bytes"
	"image"
	"log"
	"os"
	"time"

	"9fans.net/go/draw"
	"9fans.net/go/games/spacewar/pdp1"
)

func main() {
	d, err := draw.Init(nil, "", "spacewar", "512x512")
	if err != nil {
		log.Fatal(err)
	}

	var m SpacewarPDP1
	m.Init(d)
	m.PC = 4
	f := bytes.NewBuffer([]byte(spacewarCode))
	if err = m.Load(f); err != nil {
		log.Fatalf("loading %s: %s", "spacewar.lst", err)
	}
	for err == nil {
		//fmt.Printf("step PC=%06o ", m.PC);
		//fmt.Printf("inst=%06o AC=%06o IO=%06o OV=%o\n",
		//	m.Mem[m.PC], m.AC, m.IO, m.OV);
		err = m.Step()
	}
	log.Fatalf("step: %s", err)
}

func quitter(c <-chan bool) {
	<-c
	os.Exit(0)
}

// A SpacewarPDP1 is a PDP-1 machine configured to run Spacewar!
// It responds to traps by drawing on the display, and it flushes the
// display and pauses every second time the program counter reaches
// instruction 02051.
type SpacewarPDP1 struct {
	pdp1.M
	nframe    int
	frameTime time.Time
	disp      *draw.Display
	dx, dy    int
	screen    *draw.Image
	ctl       pdp1.Word
	kc        *draw.Keyboardctl
	mc        *draw.Mousectl
	cmap      []*draw.Image
	pix       [][]uint8
	oldpix    [][]uint8
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func (m *SpacewarPDP1) Init(d *draw.Display) {
	m.disp = d
	m.mc = d.InitMouse()
	m.kc = d.InitKeyboard()
	m.screen = d.ScreenImage
	m.dx = m.screen.R.Dx()
	m.dy = m.screen.R.Dy()
	m.pix = make([][]uint8, m.dy)
	m.oldpix = make([][]uint8, m.dy)
	for i := range m.pix {
		m.pix[i] = make([]uint8, m.dx)
		m.oldpix[i] = make([]uint8, m.dx)
	}
	m.cmap = make([]*draw.Image, 256)
	for i := range m.cmap {
		var r, g, b draw.Color
		r = draw.Color(min(0, 255))
		g = draw.Color(min(i*2, 255))
		b = draw.Color(min(0, 255))
		m.cmap[i], _ = d.AllocImage(image.Rect(0, 0, 1, 1), d.ScreenImage.Pix, true, r<<24|g<<16|b<<8|0xff)
	}
	m.screen.Draw(m.screen.R, d.Black, nil, image.ZP)
}

const (
	frameDelay = 56 * time.Millisecond
)

var ctlBits = [...]pdp1.Word{
	'f':  0000001,
	'd':  0000002,
	'a':  0000004,
	's':  0000010,
	'\'': 0040000,
	';':  0100000,
	'k':  0200000,
	'l':  0400000,
}

func (m *SpacewarPDP1) Step() error {
	if m.PC == 02051 {
		m.pollInput()
		m.nframe++
		if m.nframe&1 == 0 {
			m.flush()
			t := time.Now()
			if t.After(m.frameTime.Add(3 * frameDelay)) {
				m.frameTime = t
			} else {
				m.frameTime = m.frameTime.Add(frameDelay)
				for t.Before(m.frameTime) {
					time.Sleep(m.frameTime.Sub(t))
					t = time.Now()
				}
			}
		}
	}
	return m.M.Step(m)
}

func (m *SpacewarPDP1) Trap(y pdp1.Word) {
	switch y & 077 {
	case 7:
		x := int(m.AC+0400000) & 0777777
		y := int(m.IO+0400000) & 0777777
		x = x * m.dx / 0777777
		y = y * m.dy / 0777777
		if 0 <= x && x < m.dx && 0 <= y && y < m.dy {
			n := uint8(min(int(m.pix[y][x])+128, 255))
			m.pix[y][x] = n
		}
	case 011:
		m.IO = m.ctl
	}
}

func (m *SpacewarPDP1) flush() {
	// Update screen image; simulate phosphor decay.
	for y := 0; y < m.dy; y++ {
		for x := 0; x < m.dx; x++ {
			if m.oldpix[y][x] != m.pix[y][x] {
				r := image.Rect(x, y, x+1, y+1)
				m.screen.Draw(r, m.cmap[m.pix[y][x]], nil, image.ZP)
				m.oldpix[y][x] = m.pix[y][x]
			}
			m.pix[y][x] >>= 1
		}
	}
	m.disp.Flush()
}

func (m *SpacewarPDP1) pollInput() {
	for {
		select {
		case ch := <-m.kc.C:
			if 0 <= ch && ch < rune(len(ctlBits)) {
				m.ctl |= ctlBits[ch]
			}
			if 0 <= -ch && -ch < rune(len(ctlBits)) {
				m.ctl &^= ctlBits[-ch]
			}
		default:
			return
		}
	}
}
