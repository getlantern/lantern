// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin
// +build arm arm64

package app

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation -framework UIKit -framework GLKit -framework OpenGLES -framework QuartzCore
#include <sys/utsname.h>
#include <stdint.h>
#include <pthread.h>

extern struct utsname sysInfo;

void runApp(void);
void setContext(void* context);
uint64_t threadID();
*/
import "C"
import (
	"log"
	"runtime"
	"strings"
	"sync"
	"unsafe"

	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/event/paint"
	"golang.org/x/mobile/event/touch"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

var initThreadID uint64

func init() {
	// Lock the goroutine responsible for initialization to an OS thread.
	// This means the goroutine running main (and calling the run function
	// below) is locked to the OS thread that started the program. This is
	// necessary for the correct delivery of UIKit events to the process.
	//
	// A discussion on this topic:
	// https://groups.google.com/forum/#!msg/golang-nuts/IiWZ2hUuLDA/SNKYYZBelsYJ
	runtime.LockOSThread()
	initThreadID = uint64(C.threadID())
}

func main(f func(App)) {
	if tid := uint64(C.threadID()); tid != initThreadID {
		log.Fatalf("app.Run called on thread %d, but app.init ran on %d", tid, initThreadID)
	}

	go func() {
		f(app{})
		// TODO(crawshaw): trigger runApp to return
	}()
	C.runApp()
	panic("unexpected return from app.runApp")
}

var screenScale int // [UIScreen mainScreen].scale, either 1, 2, or 3.

//export setScreen
func setScreen(scale int) {
	C.uname(&C.sysInfo)
	name := C.GoString(&C.sysInfo.machine[0])

	var v float32

	switch {
	case strings.HasPrefix(name, "iPhone"):
		v = 163
	case strings.HasPrefix(name, "iPad"):
		// TODO: is there a better way to distinguish the iPad Mini?
		switch name {
		case "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7":
			v = 163 // iPad Mini
		default:
			v = 132
		}
	default:
		v = 163 // names like i386 and x86_64 are the simulator
	}

	if v == 0 {
		log.Printf("unknown machine: %s", name)
		v = 163 // emergency fallback
	}

	pixelsPerPt = v * float32(scale) / 72
	screenScale = scale
}

//export updateConfig
func updateConfig(width, height int) {
	eventsIn <- config.Event{
		Width:       geom.Pt(float32(screenScale*width) / pixelsPerPt),
		Height:      geom.Pt(float32(screenScale*height) / pixelsPerPt),
		PixelsPerPt: pixelsPerPt,
	}
}

var startedgl = false

// touchIDs is the current active touches. The position in the array
// is the ID, the value is the UITouch* pointer value.
//
// It is widely reported that the iPhone can handle up to 5 simultaneous
// touch events, while the iPad can handle 11.
var touchIDs [11]uintptr

var touchEvents struct {
	sync.Mutex
	pending []touch.Event
}

//export sendTouch
func sendTouch(cTouch, cTouchType uintptr, x, y float32) {
	id := -1
	for i, val := range touchIDs {
		if val == cTouch {
			id = i
			break
		}
	}
	if id == -1 {
		for i, val := range touchIDs {
			if val == 0 {
				touchIDs[i] = cTouch
				id = i
				break
			}
		}
		if id == -1 {
			panic("out of touchIDs")
		}
	}

	t := touch.Type(cTouchType)
	if t == touch.TypeEnd {
		touchIDs[id] = 0
	}

	eventsIn <- touch.Event{
		Sequence: touch.Sequence(id),
		Type:     t,
		Loc: geom.Point{
			X: geom.Pt(x / pixelsPerPt),
			Y: geom.Pt(y / pixelsPerPt),
		},
	}
}

//export drawgl
func drawgl(ctx uintptr) {
	if !startedgl {
		startedgl = true
		C.setContext(unsafe.Pointer(ctx))
		// TODO(crawshaw): not just on process start.
		sendLifecycle(lifecycle.StageFocused)
	}

	eventsIn <- paint.Event{}

	for {
		select {
		case <-gl.WorkAvailable:
			gl.DoWork()
		case <-endPaint:
			return
		}
	}
}
