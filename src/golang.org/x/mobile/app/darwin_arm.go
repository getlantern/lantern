// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin

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
	"sync"
	"unsafe"

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

func run(callbacks []Callbacks) {
	if tid := uint64(C.threadID()); tid != initThreadID {
		log.Fatalf("app.Run called on thread %d, but app.init ran on %d", tid, initThreadID)
	}
	cb = callbacks
	C.runApp()
}

// TODO(crawshaw): determine minimum iOS version and remove irrelevant devices.
var machinePPI = map[string]int{
	"i386":      163, // simulator
	"x86_64":    163, // simulator
	"iPod1,1":   163, // iPod Touch gen1
	"iPod2,1":   163, // iPod Touch gen2
	"iPod3,1":   163, // iPod Touch gen3
	"iPod4,1":   326, // iPod Touch gen4
	"iPod5,1":   326, // iPod Touch gen5
	"iPhone1,1": 163, // iPhone
	"iPhone1,2": 163, // iPhone 3G
	"iPhone2,1": 163, // iPhone 3GS
	"iPad1,1":   132, // iPad gen1
	"iPad2,1":   132, // iPad gen2
	"iPad2,2":   132, // iPad gen2 GSM
	"iPad2,3":   132, // iPad gen2 CDMA
	"iPad2,4":   132, // iPad gen2
	"iPad2,5":   163, // iPad Mini gen1
	"iPad2,6":   163, // iPad Mini gen1 AT&T
	"iPad2,7":   163, // iPad Mini gen1 VZ
	"iPad3,1":   264, // iPad gen3
	"iPad3,2":   264, // iPad gen3 VZ
	"iPad3,3":   264, // iPad gen3 AT&T
	"iPad3,4":   264, // iPad gen4
	"iPad3,5":   264, // iPad gen4 AT&T
	"iPad3,6":   264, // iPad gen4 VZ
	"iPad4,1":   264, // iPad Air wifi
	"iPad4,2":   264, // iPad Air LTE
	"iPad4,3":   264, // iPad Air LTE China
	"iPad4,4":   326, // iPad Mini gen2 wifi
	"iPad4,5":   326, // iPad Mini gen2 LTE
	"iPhone3,1": 326, // iPhone 4
	"iPhone4,1": 326, // iPhone 4S
	"iPhone5,1": 326, // iPhone 5
	"iPhone5,2": 326, // iPhone 5
	"iPhone5,3": 326, // iPhone 5c
	"iPhone5,4": 326, // iPhone 5c
	"iPhone6,1": 326, // iPhone 5s
	"iPhone6,2": 326, // iPhone 5s
	"iPhone7,1": 401, // iPhone 6 Plus
	"iPhone7,2": 326, // iPhone 6
}

func ppi() int {
	C.uname(&C.sysInfo)
	name := C.GoString(&C.sysInfo.machine[0])
	v, ok := machinePPI[name]
	if !ok {
		log.Fatalf("unknown machine: %s", name)
	}
	return v
}

//export setGeom
func setGeom(width, height int) {
	if geom.PixelsPerPt == 0 {
		geom.PixelsPerPt = float32(ppi()) / 72
	}
	configAlt.Width = geom.Pt(float32(width) / geom.PixelsPerPt)
	configAlt.Height = geom.Pt(float32(height) / geom.PixelsPerPt)
	configSwap(cb)
}

func initGL() {
	stateStart(cb)
}

var cb []Callbacks
var initGLOnce sync.Once

//export drawgl
func drawgl(ctx uintptr) {
	// The call to lockContext loads the OpenGL context into
	// thread-local storage for use by the underlying GL calls
	// done in the user's Draw function. We need to stay on
	// the same thread throughout Draw, so we LockOSThread.
	runtime.LockOSThread()
	C.setContext(unsafe.Pointer(ctx))

	initGLOnce.Do(initGL)

	// TODO not here?
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	for _, c := range cb {
		if c.Draw != nil {
			c.Draw()
		}
	}

	// TODO
	//C.unlockContext(ctx)

	// This may unlock the original main thread, but that's OK,
	// because by the time it does the thread has already entered
	// C.runApp, which won't give the thread up.
	runtime.UnlockOSThread()
}
