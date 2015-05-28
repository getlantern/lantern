// games/4s - a tetris clone
//
// Derived from Plan 9's /sys/src/games/xs.c
// http://plan9.bell-labs.com/sources/plan9/sys/src/games/xs.c
//
// Copyright (C) 2003, Lucent Technologies Inc. and others. All Rights Reserved.
// Portions Copyright 2009 The Go Authors.  All Rights Reserved.
// Distributed under the terms of the Lucent Public License Version 1.02
// See http://plan9.bell-labs.com/plan9/license.html

/*
 * engine for 4s, 5s, etc
 */

package main

import (
	"fmt"
	"image"
	"log"
	"math/rand"
	"os"
	"time"

	"9fans.net/go/draw"
)

/*
Cursor whitearrow = {
	{0, 0},
	{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFC,
	 0xFF, 0xF0, 0xFF, 0xF0, 0xFF, 0xF8, 0xFF, 0xFC,
	 0xFF, 0xFE, 0xFF, 0xFF, 0xFF, 0xFE, 0xFF, 0xFC,
	 0xF3, 0xF8, 0xF1, 0xF0, 0xE0, 0xE0, 0xC0, 0x40, },
	{0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0x06, 0xC0, 0x1C,
	 0xC0, 0x30, 0xC0, 0x30, 0xC0, 0x38, 0xC0, 0x1C,
	 0xC0, 0x0E, 0xC0, 0x07, 0xCE, 0x0E, 0xDF, 0x1C,
	 0xD3, 0xB8, 0xF1, 0xF0, 0xE0, 0xE0, 0xC0, 0x40, }
};
*/

const (
	CNone   = 0
	CBounds = 1
	CPiece  = 2
	NX      = 10
	NY      = 20

	NCOL = 10

	MAXN = 5
)

var (
	N       int
	display *draw.Display
	screen  *draw.Image
	screenr image.Rectangle

	board                    [NY][NX]byte
	rboard                   image.Rectangle
	pscore                   image.Point
	scoresz                  image.Point
	pcsz                     = 32
	pos                      image.Point
	bb, bbmask, bb2, bb2mask *draw.Image
	whitemask                *draw.Image
	br, br2                  image.Rectangle
	points                   int
	dt                       int
	DY                       int
	DMOUSE                   int
	lastmx                   int
	mouse                    draw.Mouse
	newscreen                bool
	timerc                   <-chan time.Time
	suspc                    chan bool
	mousec                   chan draw.Mouse
	kbdc                     chan rune
	mousectl                 *draw.Mousectl
	kbdctl                   *draw.Keyboardctl
	suspended                bool
	tsleep                   int
	piece                    *Piece
	pieces                   []Piece
)

type Piece struct {
	rot   int
	tx    int
	sz    image.Point
	d     []image.Point
	left  *Piece
	right *Piece
}

var txbits = [NCOL][32]byte{
	[32]byte{0xDD, 0xDD, 0xFF, 0xFF, 0x77, 0x77, 0xFF, 0xFF,
		0xDD, 0xDD, 0xFF, 0xFF, 0x77, 0x77, 0xFF, 0xFF,
		0xDD, 0xDD, 0xFF, 0xFF, 0x77, 0x77, 0xFF, 0xFF,
		0xDD, 0xDD, 0xFF, 0xFF, 0x77, 0x77, 0xFF, 0xFF},
	[32]byte{0xDD, 0xDD, 0x77, 0x77, 0xDD, 0xDD, 0x77, 0x77,
		0xDD, 0xDD, 0x77, 0x77, 0xDD, 0xDD, 0x77, 0x77,
		0xDD, 0xDD, 0x77, 0x77, 0xDD, 0xDD, 0x77, 0x77,
		0xDD, 0xDD, 0x77, 0x77, 0xDD, 0xDD, 0x77, 0x77},
	[32]byte{0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55,
		0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55,
		0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55,
		0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55},
	[32]byte{0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55,
		0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55,
		0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55,
		0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55},
	[32]byte{0x22, 0x22, 0x88, 0x88, 0x22, 0x22, 0x88, 0x88,
		0x22, 0x22, 0x88, 0x88, 0x22, 0x22, 0x88, 0x88,
		0x22, 0x22, 0x88, 0x88, 0x22, 0x22, 0x88, 0x88,
		0x22, 0x22, 0x88, 0x88, 0x22, 0x22, 0x88, 0x88},
	[32]byte{0x22, 0x22, 0x00, 0x00, 0x88, 0x88, 0x00, 0x00,
		0x22, 0x22, 0x00, 0x00, 0x88, 0x88, 0x00, 0x00,
		0x22, 0x22, 0x00, 0x00, 0x88, 0x88, 0x00, 0x00,
		0x22, 0x22, 0x00, 0x00, 0x88, 0x88, 0x00, 0x00},
	[32]byte{0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00},
	[32]byte{0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00},
	[32]byte{0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC,
		0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC,
		0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC,
		0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC, 0xCC},
	[32]byte{0xCC, 0xCC, 0xCC, 0xCC, 0x33, 0x33, 0x33, 0x33,
		0xCC, 0xCC, 0xCC, 0xCC, 0x33, 0x33, 0x33, 0x33,
		0xCC, 0xCC, 0xCC, 0xCC, 0x33, 0x33, 0x33, 0x33,
		0xCC, 0xCC, 0xCC, 0xCC, 0x33, 0x33, 0x33, 0x33},
}

var txpix = [NCOL]draw.Color{
	draw.Yellow,    /* yellow */
	draw.Cyan,      /* cyan */
	draw.Green,     /* lime green */
	draw.Greyblue,  /* slate */
	draw.Red,       /* red */
	draw.Greygreen, /* olive green */
	draw.Blue,      /* blue */
	0xFF55AAFF,     /* pink */
	0xFFAAFFFF,     /* lavender */
	0xBB005DFF,     /* maroon */
}

var tx [NCOL]*draw.Image

func movemouse() int {
	mouse.Point = image.Pt(rboard.Min.X+rboard.Dx()/2, rboard.Min.Y+rboard.Dy()/2)
	//mousectl.MoveTo(mouse.Point)
	return mouse.X
}

func warp(p image.Point, x int) int {
	if !suspended && piece != nil {
		x = pos.X + piece.sz.X*pcsz/2
		if p.Y < rboard.Min.Y {
			p.Y = rboard.Min.Y
		}
		if p.Y >= rboard.Max.Y {
			p.Y = rboard.Max.Y - 1
		}
		//mousectl.MoveTo(image.Pt(x, p.Y))
	}
	return x
}

func initPieces() {
	for i := range pieces {
		p := &pieces[i]
		if p.rot == 3 {
			p.right = &pieces[i-3]
		} else {
			p.right = &pieces[i+1]
		}
		if p.rot == 0 {
			p.left = &pieces[i+3]
		} else {
			p.left = &pieces[i-1]
		}
	}
}

func collide(pt image.Point, p *Piece) bool {
	pt.X = (pt.X - rboard.Min.X) / pcsz
	pt.Y = (pt.Y - rboard.Min.Y) / pcsz
	for _, q := range p.d {
		pt.X += q.X
		pt.Y += q.Y
		if pt.X < 0 || pt.X >= NX || pt.Y < 0 || pt.Y >= NY {
			return true
		}
		if board[pt.Y][pt.X] != 0 {
			return true
		}
	}
	return false
}

func collider(pt, pmax image.Point) bool {
	pi := (pt.X - rboard.Min.X) / pcsz
	pj := (pt.Y - rboard.Min.Y) / pcsz
	n := pmax.X / pcsz
	m := pmax.Y/pcsz + 1
	for i := pi; i < pi+n && i < NX; i++ {
		for j := pj; j < pj+m && j < NY; j++ {
			if board[j][i] != 0 {
				return true
			}
		}
	}
	return false
}

func setpiece(p *Piece) {
	bb.Draw(bb.R, display.White, nil, image.ZP)
	bbmask.Draw(bb.R, display.Transparent, nil, image.ZP)
	br = image.Rect(0, 0, 0, 0)
	br2 = br
	piece = p
	if p == nil {
		return
	}
	var op image.Point
	var r image.Rectangle
	r.Min = bb.R.Min
	for i, pt := range p.d {
		r.Min.X += pt.X * pcsz
		r.Min.Y += pt.Y * pcsz
		r.Max.X = r.Min.X + pcsz
		r.Max.Y = r.Min.Y + pcsz
		if i == 0 {
			bb.Draw(r, display.Black, nil, image.ZP)
			bb.Draw(r.Inset(1), tx[piece.tx], nil, image.ZP)
			bbmask.Draw(r, display.Opaque, nil, image.ZP)
			op = r.Min
		} else {
			bb.Draw(r, bb, nil, op)
			bbmask.Draw(r, bbmask, nil, op)
		}
		if br.Max.X < r.Max.X {
			br.Max.X = r.Max.X
		}
		if br.Max.Y < r.Max.Y {
			br.Max.Y = r.Max.Y
		}
	}
	br.Max = br.Max.Sub(bb.R.Min)
	delta := image.Pt(0, DY)
	br2.Max = br.Max.Add(delta)
	r = br.Add(bb2.R.Min)
	r2 := br2.Add(bb2.R.Min)
	bb2.Draw(r2, display.White, nil, image.ZP)
	bb2.Draw(r.Add(delta), bb, nil, bb.R.Min)
	bb2mask.Draw(r2, display.Transparent, nil, image.ZP)
	bb2mask.Draw(r, display.Opaque, bbmask, bb.R.Min)
	bb2mask.Draw(r.Add(delta), display.Opaque, bbmask, bb.R.Min)
}

func drawpiece() {
	screen.Draw(br.Add(pos), bb, bbmask, bb.R.Min)
	if suspended {
		screen.Draw(br.Add(pos), display.White, whitemask, image.ZP)
	}
}

func undrawpiece() {
	var mask *draw.Image
	if collider(pos, br.Max) {
		mask = bbmask
	}
	screen.Draw(br.Add(pos), display.White, mask, bb.R.Min)
}

func rest() {
	pt := pos.Sub(rboard.Min).Div(pcsz)
	for _, p := range piece.d {
		pt.X += p.X
		pt.Y += p.Y
		board[pt.Y][pt.X] = byte(piece.tx + 16)
	}
}

func canfit(p *Piece) bool {
	var dx = [...]int{0, -1, 1, -2, 2, -3, 3, 4, -4}
	j := N + 1
	if j >= 4 {
		j = p.sz.X
		if j < p.sz.Y {
			j = p.sz.Y
		}
		j = 2*j - 1
	}
	for i := 0; i < j; i++ {
		var z image.Point
		z.X = pos.X + dx[i]*pcsz
		z.Y = pos.Y
		if !collide(z, p) {
			z.Y = pos.Y + pcsz - 1
			if !collide(z, p) {
				undrawpiece()
				pos.X = z.X
				return true
			}
		}
	}
	return false
}

func score(p int) {
	points += p
	buf := fmt.Sprintf("%.6d", points)
	screen.Draw(image.Rectangle{pscore, pscore.Add(scoresz)}, display.White, nil, image.ZP)
	screen.String(pscore, display.Black, image.ZP, display.DefaultFont, buf)
}

func drawsq(b *draw.Image, p image.Point, ptx int) {
	var r image.Rectangle
	r.Min = p
	r.Max.X = r.Min.X + pcsz
	r.Max.Y = r.Min.Y + pcsz
	b.Draw(r, display.Black, nil, image.ZP)
	b.Draw(r.Inset(1), tx[ptx], nil, image.ZP)
}

func drawboard() {
	screen.Border(rboard.Inset(-2), 2, display.Black, image.ZP)
	screen.Draw(image.Rect(rboard.Min.X, rboard.Min.Y-2, rboard.Max.X, rboard.Min.Y),
		display.White, nil, image.ZP)
	for i := 0; i < NY; i++ {
		for j := 0; j < NX; j++ {
			if board[i][j] != 0 {
				drawsq(screen, image.Pt(rboard.Min.X+j*pcsz, rboard.Min.Y+i*pcsz), int(board[i][j]-16))
			}
		}
	}
	score(0)
	if suspended {
		screen.Draw(screenr, display.White, whitemask, image.ZP)
	}
}

func choosepiece() {
	for {
		i := rand.Intn(len(pieces))
		setpiece(&pieces[i])
		pos = rboard.Min
		pos.X += rand.Intn(NX) * pcsz
		if !collide(image.Pt(pos.X, pos.Y+pcsz-DY), piece) {
			break
		}
	}
	drawpiece()
	display.Flush()
}

func movepiece() bool {
	var mask *draw.Image
	if collide(image.Pt(pos.X, pos.Y+pcsz), piece) {
		return false
	}
	if collider(pos, br2.Max) {
		mask = bb2mask
	}
	screen.Draw(br2.Add(pos), bb2, mask, bb2.R.Min)
	pos.Y += DY
	display.Flush()
	return true
}

func suspend(s bool) {
	suspended = s
	/*
		if suspended {
			setcursor(mousectl, &whitearrow);
		} else {
			setcursor(mousectl, nil);
		}
	*/
	if !suspended {
		drawpiece()
	}
	drawboard()
	display.Flush()
}

func pause(t int) {
	display.Flush()
	for {
		select {
		case s := <-suspc:
			if !suspended && s {
				suspend(true)
			} else if suspended && !s {
				suspend(false)
				lastmx = warp(mouse.Point, lastmx)
			}
		case <-timerc:
			if suspended {
				break
			}
			t -= tsleep
			if t < 0 {
				return
			}
		case <-mousectl.Resize:
			redraw(true)
		case mouse = <-mousec:
		case <-kbdc:
		}
	}
}

func horiz() bool {
	var lev [MAXN]int
	h := 0
	for i := 0; i < NY; i++ {
		for j := 0; board[i][j] != 0; j++ {
			if j == NX-1 {
				lev[h] = i
				h++
				break
			}
		}
	}
	if h == 0 {
		return false
	}
	r := rboard
	newscreen = false
	for j := 0; j < h; j++ {
		r.Min.Y = rboard.Min.Y + lev[j]*pcsz
		r.Max.Y = r.Min.Y + pcsz
		screen.Draw(r, display.White, whitemask, image.ZP)
		display.Flush()
	}
	for i := 0; i < 3; i++ {
		pause(250)
		if newscreen {
			drawboard()
			break
		}
		for j := 0; j < h; j++ {
			r.Min.Y = rboard.Min.Y + lev[j]*pcsz
			r.Max.Y = r.Min.Y + pcsz
			screen.Draw(r, display.White, whitemask, image.ZP)
		}
		display.Flush()
	}
	r = rboard
	for j := 0; j < h; j++ {
		i := NY - lev[j] - 1
		score(250 + 10*i*i)
		r.Min.Y = rboard.Min.Y
		r.Max.Y = rboard.Min.Y + lev[j]*pcsz
		screen.Draw(r.Add(image.Pt(0, pcsz)), screen, nil, r.Min)
		r.Max.Y = rboard.Min.Y + pcsz
		screen.Draw(r, display.White, nil, image.ZP)
		for k := lev[j] - 1; k >= 0; k-- {
			board[k+1] = board[k]
		}
		board[0] = [NX]byte{}
	}
	display.Flush()
	return true
}

func mright() {
	if !collide(image.Pt(pos.X+pcsz, pos.Y), piece) && !collide(image.Pt(pos.X+pcsz, pos.Y+pcsz-DY), piece) {
		undrawpiece()
		pos.X += pcsz
		drawpiece()
		display.Flush()
	}
}

func mleft() {
	if !collide(image.Pt(pos.X-pcsz, pos.Y), piece) && !collide(image.Pt(pos.X-pcsz, pos.Y+pcsz-DY), piece) {
		undrawpiece()
		pos.X -= pcsz
		drawpiece()
		display.Flush()
	}
}

func rright() {
	if canfit(piece.right) {
		setpiece(piece.right)
		drawpiece()
		display.Flush()
	}
}

func rleft() {
	if canfit(piece.left) {
		setpiece(piece.left)
		drawpiece()
		display.Flush()
	}
}

var fusst = 0

func drop(f bool) bool {
	if f {
		score(5 * (rboard.Max.Y - pos.Y) / pcsz)
		for movepiece() {
		}
	}
	fusst = 0
	rest()
	if pos.Y == rboard.Min.Y && !horiz() {
		return true
	}
	horiz()
	setpiece(nil)
	pause(1500)
	choosepiece()
	lastmx = warp(mouse.Point, lastmx)
	return false
}

func play() {
	var om draw.Mouse
	dt = 64
	lastmx = -1
	lastmx = movemouse()
	choosepiece()
	lastmx = warp(mouse.Point, lastmx)
	for {
		select {
		case mouse = <-mousec:
			if suspended {
				om = mouse
				break
			}
			if lastmx < 0 {
				lastmx = mouse.X
			}
			if mouse.X > lastmx+DMOUSE {
				mright()
				lastmx = mouse.X
			}
			if mouse.X < lastmx-DMOUSE {
				mleft()
				lastmx = mouse.X
			}
			if mouse.Buttons&^om.Buttons&1 == 1 {
				rleft()
			}
			if mouse.Buttons&^om.Buttons&2 == 2 {
				if drop(true) {
					return
				}
			}
			if mouse.Buttons&^om.Buttons&4 == 4 {
				rright()
			}
			om = mouse

		case s := <-suspc:
			if !suspended && s {
				suspend(true)
			} else if suspended && !s {
				suspend(false)
				lastmx = warp(mouse.Point, lastmx)
			}

		case <-mousectl.Resize:
			redraw(true)

		case r := <-kbdc:
			if suspended {
				break
			}
			switch r {
			case 'f', ';':
				mright()
			case 'a', 'j':
				mleft()
			case 'd', 'l':
				rright()
			case 's', 'k':
				rleft()
			case ' ':
				if drop(true) {
					return
				}
			}

		case <-timerc:
			if suspended {
				break
			}
			dt -= tsleep
			if dt < 0 {
				i := 1
				dt = 16 * (points + rand.Intn(10000) - 5000) / 10000
				if dt >= 32 {
					i += (dt - 32) / 16
					dt = 32
				}
				dt = 52 - dt
				for ; i > 0; i-- {
					if movepiece() {
						continue
					}
					fusst++
					if fusst == 40 {
						if drop(false) {
							return
						}
						break
					}
				}
			}
		}
	}
}

func suspproc() {
	s := false
	for {
		select {
		case mouse = <-mousectl.C:
			mousec <- mouse
		case r := <-kbdctl.C:
			switch r {
			case 'q', 'Q', 0x04, 0x7F:
				os.Exit(0)
			default:
				if s {
					s = false
					suspc <- s
					break
				}
				switch r {
				case 'z', 'Z', 'p', 'P', 0x1B:
					s = true
					suspc <- s
				default:
					kbdc <- r
				}
			}
		}
	}
}

func redraw(new bool) {
	if new {
		if err := display.Attach(draw.Refmesg); err != nil {
			log.Fatalf("can't reattach to window: %v", err)
		}
	}

	r := screen.R
	pos.X = (pos.X - rboard.Min.X) / pcsz
	pos.Y = (pos.Y - rboard.Min.Y) / pcsz
	dx := r.Max.X - r.Min.X
	dy := r.Max.Y - r.Min.Y - 2*32
	DY = dx / NX
	if DY > dy/NY {
		DY = dy / NY
	}
	DY /= 8
	if DY > 4 {
		DY = 4
	}
	pcsz = DY * 8
	DMOUSE = pcsz / 3
	if pcsz < 8 {
		log.Fatalf("screen too small: %d", pcsz)
	}
	rboard = screenr
	rboard.Min.X += (dx - pcsz*NX) / 2
	rboard.Min.Y += (dy-pcsz*NY)/2 + 32
	rboard.Max.X = rboard.Min.X + NX*pcsz
	rboard.Max.Y = rboard.Min.Y + NY*pcsz
	pscore.X = rboard.Min.X + 8
	pscore.Y = rboard.Min.Y - 32
	scoresz = display.DefaultFont.StringSize("000000")
	pos.X = pos.X*pcsz + rboard.Min.X
	pos.Y = pos.Y*pcsz + rboard.Min.Y
	if bb != nil {
		bb.Free()
		bbmask.Free()
		bb2.Free()
		bb2mask.Free()
	}
	bb, _ = display.AllocImage(image.Rect(0, 0, N*pcsz, N*pcsz), screen.Pix, false, 0)
	bbmask, _ = display.AllocImage(image.Rect(0, 0, N*pcsz, N*pcsz), draw.GREY1, false, 0)
	bb2, _ = display.AllocImage(image.Rect(0, 0, N*pcsz, N*pcsz+DY), screen.Pix, false, 0)
	bb2mask, _ = display.AllocImage(image.Rect(0, 0, N*pcsz, N*pcsz+DY), draw.GREY1, false, 0)
	screen.Draw(screenr, display.White, nil, image.ZP)
	drawboard()
	setpiece(piece)
	if piece != nil {
		drawpiece()
	}
	lastmx = movemouse()
	newscreen = true
	display.Flush()
}

func Play(pp []Piece, d *draw.Display) {
	pieces = pp
	N = len(pieces[0].d)
	initPieces()
	display = d
	screen = d.ScreenImage

	mousectl = d.InitMouse()
	kbdctl = d.InitKeyboard()
	rand.Seed(int64(time.Now().UnixNano() % (1e9 - 1)))
	for i, col := range txpix {
		tx[i], _ = d.AllocImage(image.Rect(0, 0, 1, 1), screen.Pix, true, col)
	}
	whitemask, _ = display.AllocImage(image.Rect(0, 0, 1, 1), draw.ARGB32, true, 0x7F7F7F7F)
	tsleep = 50
	timerc = time.Tick(time.Duration(tsleep/2) * time.Millisecond)
	suspc = make(chan bool)
	mousec = make(chan draw.Mouse)
	kbdc = make(chan rune)
	go suspproc()
	redraw(false)
	play()
}
