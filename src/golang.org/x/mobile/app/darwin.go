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

func run(callbacks Callbacks) {
	if tid := uint64(C.threadID()); tid != initThreadID {
		log.Fatalf("app.Run called on thread %d, but app.init ran on %d", tid, initThreadID)
	}
	cb = callbacks
	C.runApp()
}

//export setGeom
func setGeom(pixelsPerPt float32, width, height int) {
	// Macs default to 72 DPI, so scales are equivalent.
	geom.PixelsPerPt = pixelsPerPt
	geom.Width = geom.Pt(float32(width) / pixelsPerPt)
	geom.Height = geom.Pt(float32(height) / pixelsPerPt)
}

func initGL() {
	// Using attribute arrays in OpenGL 3.3 requires the use of a VBA.
	// But VBAs don't exist in ES 2. So we bind a default one.
	var id C.GLuint
	C.glGenVertexArrays(1, &id)
	C.glBindVertexArray(id)
	if cb.Start != nil {
		cb.Start()
	}
}

var cb Callbacks
var initGLOnce sync.Once

var events struct {
	sync.Mutex
	pending []event.Touch
}

func sendTouch(ty event.TouchType, x, y float32) {
	events.Lock()
	events.pending = append(events.pending, event.Touch{
		Type: ty,
		Loc: geom.Point{
			X: geom.Pt(x / geom.PixelsPerPt),
			Y: geom.Height - geom.Pt(y/geom.PixelsPerPt),
		},
	})
	events.Unlock()
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

	events.Lock()
	pending := events.pending
	events.pending = nil
	events.Unlock()
	for _, e := range pending {
		if cb.Touch != nil {
			cb.Touch(e)
		}
	}

	// TODO: is the library or the app responsible for clearing the buffers?
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	if cb.Draw != nil {
		cb.Draw()
	}

	C.unlockContext(ctx)

	// This may unlock the original main thread, but that's OK,
	// because by the time it does the thread has already entered
	// C.runApp, which won't give the thread up.
	runtime.UnlockOSThread()
}
