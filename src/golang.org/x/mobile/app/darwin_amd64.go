// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin

package app

// Simple on-screen app debugging for OS X. Not an officially supported
// development target for apps, as screens with mice are very different
// than screens with touch panels.

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Cocoa -framework OpenGL -framework QuartzCore
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#include <pthread.h>

void glGenVertexArrays(GLsizei n, GLuint* array);
void glBindVertexArray(GLuint array);

void runApp(void);
void lockContext(GLintptr);
void unlockContext(GLintptr);
double backingScaleFactor();
uint64 threadID();

*/
import "C"
import (
	"log"
	"runtime"
	"sync"

	"golang.org/x/mobile/event"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

var initThreadID uint64

func init() {
	// Lock the goroutine responsible for initialization to an OS thread.
	// This means the goroutine running main (and calling the run function
	// below) is locked to the OS thread that started the program. This is
	// necessary for the correct delivery of Cocoa events to the process.
	//
	// A discussion on this topic:
	// https://groups.google.com/forum/#!msg/golang-nuts/IiWZ2hUuLDA/SNKYYZBelsYJ
	runtime.LockOSThread()
	initThreadID = uint64(C.threadID())
}

func run(callbacks []Callbacks) {
	if tid := uint64(C.threadID()); tid != initThreadID {
		log.Fatalf("app.Run called on thread %d, but app.init ran on %d", tid, initThreadID)
	}
	close(mainCalled)
	C.runApp()
}

//export setGeom
func setGeom(pixelsPerPt float32, width, height int) {
	if geom.PixelsPerPt == 0 {
		// Macs default to 72 DPI, so scales are equivalent.
		geom.PixelsPerPt = pixelsPerPt
	}
	configAlt.Width = geom.Pt(float32(width) / geom.PixelsPerPt)
	configAlt.Height = geom.Pt(float32(height) / geom.PixelsPerPt)
	configSwap(callbacks)
}

func initGL() {
	// Using attribute arrays in OpenGL 3.3 requires the use of a VBA.
	// But VBAs don't exist in ES 2. So we bind a default one.
	var id C.GLuint
	C.glGenVertexArrays(1, &id)
	C.glBindVertexArray(id)
	stateStart(callbacks)
}

var initGLOnce sync.Once

var touchEvents struct {
	sync.Mutex
	pending []event.Touch
}

func sendTouch(ty event.TouchType, x, y float32) {
	touchEvents.Lock()
	touchEvents.pending = append(touchEvents.pending, event.Touch{
		ID:   0,
		Type: ty,
		Loc: geom.Point{
			X: geom.Pt(x / geom.PixelsPerPt),
			Y: GetConfig().Height - geom.Pt(y/geom.PixelsPerPt),
		},
	})
	touchEvents.Unlock()
}

//export eventMouseDown
func eventMouseDown(x, y float32) { sendTouch(event.TouchStart, x, y) }

//export eventMouseDragged
func eventMouseDragged(x, y float32) { sendTouch(event.TouchMove, x, y) }

//export eventMouseEnd
func eventMouseEnd(x, y float32) { sendTouch(event.TouchEnd, x, y) }

//export drawgl
func drawgl(ctx C.GLintptr) {
	// The call to lockContext loads the OpenGL context into
	// thread-local storage for use by the underlying GL calls
	// done in the user's Draw function. We need to stay on
	// the same thread throughout Draw, so we LockOSThread.
	runtime.LockOSThread()
	C.lockContext(ctx)

	initGLOnce.Do(initGL)

	touchEvents.Lock()
	pending := touchEvents.pending
	touchEvents.pending = nil
	touchEvents.Unlock()
	for _, cb := range callbacks {
		if cb.Touch != nil {
			for _, e := range pending {
				cb.Touch(e)
			}
		}
	}

	// TODO: is the library or the app responsible for clearing the buffers?
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	for _, cb := range callbacks {
		if cb.Draw != nil {
			cb.Draw()
		}
	}

	C.unlockContext(ctx)

	// This may unlock the original main thread, but that's OK,
	// because by the time it does the thread has already entered
	// C.runApp, which won't give the thread up.
	runtime.UnlockOSThread()
}
