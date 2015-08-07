// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux,!android

package app

/*
Simple on-screen app debugging for X11. Not an officially supported
development target for apps, as screens with mice are very different
than screens with touch panels.

On Ubuntu 14.04 'Trusty', you may have to install these libraries:
sudo apt-get install libegl1-mesa-dev libgles2-mesa-dev libx11-dev
*/

/*
#cgo LDFLAGS: -lEGL -lGLESv2 -lX11

void createWindow(void);
void processEvents(void);
void swapBuffers(void);
*/
import "C"
import (
	"runtime"
	"time"

	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/event/paint"
	"golang.org/x/mobile/event/touch"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

func init() {
	registerGLViewportFilter()
}

func main(f func(App)) {
	runtime.LockOSThread()
	C.createWindow()

	// TODO: send lifecycle events when e.g. the X11 window is iconified or moved off-screen.
	sendLifecycle(lifecycle.StageFocused)

	donec := make(chan struct{})
	go func() {
		f(app{})
		close(donec)
	}()

	// TODO: can we get the actual vsync signal?
	ticker := time.NewTicker(time.Second / 60)
	defer ticker.Stop()
	tc := ticker.C

	for {
		select {
		case <-donec:
			return
		case <-gl.WorkAvailable:
			gl.DoWork()
		case <-endPaint:
			C.swapBuffers()
			tc = ticker.C
		case <-tc:
			tc = nil
			eventsIn <- paint.Event{}
		}
		C.processEvents()
	}
}

//export onResize
func onResize(w, h int) {
	// TODO(nigeltao): don't assume 72 DPI. DisplayWidth and DisplayWidthMM
	// is probably the best place to start looking.
	pixelsPerPt = 1
	eventsIn <- config.Event{
		Width:       geom.Pt(w),
		Height:      geom.Pt(h),
		PixelsPerPt: pixelsPerPt,
	}
}

func sendTouch(t touch.Type, x, y float32) {
	eventsIn <- touch.Event{
		Sequence: 0, // TODO: button??
		Type:     t,
		Loc: geom.Point{
			X: geom.Pt(x / pixelsPerPt),
			Y: geom.Pt(y / pixelsPerPt),
		},
	}
}

//export onTouchBegin
func onTouchBegin(x, y float32) { sendTouch(touch.TypeBegin, x, y) }

//export onTouchMove
func onTouchMove(x, y float32) { sendTouch(touch.TypeMove, x, y) }

//export onTouchEnd
func onTouchEnd(x, y float32) { sendTouch(touch.TypeEnd, x, y) }

var stopped bool

//export onStop
func onStop() {
	if stopped {
		return
	}
	stopped = true
	sendLifecycle(lifecycle.StageDead)
	eventsIn <- stopPumping{}
}
