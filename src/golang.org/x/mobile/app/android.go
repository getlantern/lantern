// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android

/*
Android Apps are built with -buildmode=c-shared. They are loaded by a
running Java process.

Before any entry point is reached, a global constructor initializes the
Go runtime, calling all Go init functions. All cgo calls will block
until this is complete. Next JNI_OnLoad is called. When that is
complete, one of two entry points is called.

All-Go apps built using NativeActivity enter at ANativeActivity_onCreate.

Go libraries (for example, those built with gomobile bind) do not use
the app package initialization.
*/

package app

/*
#cgo LDFLAGS: -landroid -llog -lEGL -lGLESv2

#include <android/configuration.h>
#include <android/native_activity.h>
#include <android/native_window.h>
#include <EGL/egl.h>
#include <jni.h>
#include <pthread.h>
#include <stdlib.h>

jclass current_ctx_clazz;

jclass app_find_class(JNIEnv* env, const char* name);

EGLDisplay display;
EGLSurface surface;

char* initEGLDisplay();
char* createEGLSurface(ANativeWindow* window);
char* destroyEGLSurface();
*/
import "C"
import (
	"fmt"
	"log"
	"os"
	"runtime"
	"time"
	"unsafe"

	"golang.org/x/mobile/app/internal/callfn"
	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/event/paint"
	"golang.org/x/mobile/event/touch"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
	"golang.org/x/mobile/internal/mobileinit"
)

//export setCurrentContext
func setCurrentContext(vm *C.JavaVM, ctx C.jobject) {
	mobileinit.SetCurrentContext(unsafe.Pointer(vm), unsafe.Pointer(ctx))
}

//export callMain
func callMain(mainPC uintptr) {
	for _, name := range []string{"TMPDIR", "PATH", "LD_LIBRARY_PATH"} {
		n := C.CString(name)
		os.Setenv(name, C.GoString(C.getenv(n)))
		C.free(unsafe.Pointer(n))
	}

	// Set timezone.
	//
	// Note that Android zoneinfo is stored in /system/usr/share/zoneinfo,
	// but it is in some kind of packed TZiff file that we do not support
	// yet. As a stopgap, we build a fixed zone using the tm_zone name.
	var curtime C.time_t
	var curtm C.struct_tm
	C.time(&curtime)
	C.localtime_r(&curtime, &curtm)
	tzOffset := int(curtm.tm_gmtoff)
	tz := C.GoString(curtm.tm_zone)
	time.Local = time.FixedZone(tz, tzOffset)

	go callfn.CallFn(mainPC)
}

//export onStart
func onStart(activity *C.ANativeActivity) {
}

//export onResume
func onResume(activity *C.ANativeActivity) {
}

//export onSaveInstanceState
func onSaveInstanceState(activity *C.ANativeActivity, outSize *C.size_t) unsafe.Pointer {
	return nil
}

//export onPause
func onPause(activity *C.ANativeActivity) {
}

//export onStop
func onStop(activity *C.ANativeActivity) {
}

//export onCreate
func onCreate(activity *C.ANativeActivity) {
	// Set the initial configuration.
	//
	// Note we use unbuffered channels to talk to the activity loop, and
	// NativeActivity calls these callbacks sequentially, so configuration
	// will be set before <-windowRedrawNeeded is processed.
	windowConfigChange <- windowConfigRead(activity)
}

//export onDestroy
func onDestroy(activity *C.ANativeActivity) {
}

//export onWindowFocusChanged
func onWindowFocusChanged(activity *C.ANativeActivity, hasFocus int) {
}

//export onNativeWindowCreated
func onNativeWindowCreated(activity *C.ANativeActivity, w *C.ANativeWindow) {
	windowCreated <- w
}

//export onNativeWindowRedrawNeeded
func onNativeWindowRedrawNeeded(activity *C.ANativeActivity, window *C.ANativeWindow) {
	// Called on orientation change and window resize.
	// Send a request for redraw, and block this function
	// until a complete draw and buffer swap is completed.
	// This is required by the redraw documentation to
	// avoid bad draws.
	windowRedrawNeeded <- window
	<-windowRedrawDone
}

//export onNativeWindowDestroyed
func onNativeWindowDestroyed(activity *C.ANativeActivity, window *C.ANativeWindow) {
	windowDestroyed <- window
}

//export onInputQueueCreated
func onInputQueueCreated(activity *C.ANativeActivity, q *C.AInputQueue) {
	inputQueue <- q
}

//export onInputQueueDestroyed
func onInputQueueDestroyed(activity *C.ANativeActivity, q *C.AInputQueue) {
	inputQueue <- nil
}

//export onContentRectChanged
func onContentRectChanged(activity *C.ANativeActivity, rect *C.ARect) {
}

type windowConfig struct {
	// TODO(crawshaw): report orientation
	//	ACONFIGURATION_ORIENTATION_ANY
	//	ACONFIGURATION_ORIENTATION_PORT
	//	ACONFIGURATION_ORIENTATION_LAND
	//	ACONFIGURATION_ORIENTATION_SQUARE
	// Needs to be merged with iOS's notion of orientation first.
	orientation int
	pixelsPerPt float32
}

func windowConfigRead(activity *C.ANativeActivity) windowConfig {
	aconfig := C.AConfiguration_new()
	C.AConfiguration_fromAssetManager(aconfig, activity.assetManager)
	orient := C.AConfiguration_getOrientation(aconfig)
	density := C.AConfiguration_getDensity(aconfig)
	C.AConfiguration_delete(aconfig)

	var dpi int
	switch density {
	case C.ACONFIGURATION_DENSITY_DEFAULT:
		dpi = 160
	case C.ACONFIGURATION_DENSITY_LOW,
		C.ACONFIGURATION_DENSITY_MEDIUM,
		213, // C.ACONFIGURATION_DENSITY_TV
		C.ACONFIGURATION_DENSITY_HIGH,
		320, // ACONFIGURATION_DENSITY_XHIGH
		480, // ACONFIGURATION_DENSITY_XXHIGH
		640: // ACONFIGURATION_DENSITY_XXXHIGH
		dpi = int(density)
	case C.ACONFIGURATION_DENSITY_NONE:
		log.Print("android device reports no screen density")
		dpi = 72
	default:
		log.Printf("android device reports unknown density: %d", density)
		// All we can do is guess.
		if density > 0 {
			dpi = int(density)
		} else {
			dpi = 72
		}
	}

	return windowConfig{
		orientation: int(orient),
		pixelsPerPt: float32(dpi) / 72,
	}
}

//export onConfigurationChanged
func onConfigurationChanged(activity *C.ANativeActivity) {
	// A rotation event first triggers onConfigurationChanged, then
	// calls onNativeWindowRedrawNeeded. We extract the orientation
	// here and save it for the redraw event.
	windowConfigChange <- windowConfigRead(activity)
}

//export onLowMemory
func onLowMemory(activity *C.ANativeActivity) {
}

var (
	inputQueue         = make(chan *C.AInputQueue)
	windowDestroyed    = make(chan *C.ANativeWindow)
	windowCreated      = make(chan *C.ANativeWindow)
	windowRedrawNeeded = make(chan *C.ANativeWindow)
	windowRedrawDone   = make(chan struct{})
	windowConfigChange = make(chan windowConfig)
)

func init() {
	registerGLViewportFilter()
}

func main(f func(App)) {
	// Preserve this OS thread for the GL context created below.
	runtime.LockOSThread()

	donec := make(chan struct{})
	go func() {
		f(app{})
		close(donec)
	}()

	var q *C.AInputQueue

	// Android can send a windowRedrawNeeded event any time, including
	// in the middle of a paint cycle. The redraw event may have changed
	// the size of the screen, so any partial painting is now invalidated.
	// We must also not return to Android (via sending on windowRedrawDone)
	// until a complete paint with the new configuration is complete.
	//
	// When a windowRedrawNeeded request comes in, we increment redrawGen
	// (Gen is short for generation number), and do not make a paint cycle
	// visible on <-endPaint unless Generation agrees. If possible,
	// windowRedrawDone is signalled, allowing onNativeWindowRedrawNeeded
	// to return.
	var redrawGen uint32

	for {
		if q != nil {
			processEvents(q)
		}
		select {
		case <-windowCreated:
		case q = <-inputQueue:
		case <-donec:
			return
		case cfg := <-windowConfigChange:
			// TODO save orientation
			pixelsPerPt = cfg.pixelsPerPt
		case w := <-windowRedrawNeeded:
			newWindow := C.surface == nil
			if newWindow {
				if errStr := C.createEGLSurface(w); errStr != nil {
					log.Printf("app: %s (%s)", C.GoString(errStr), eglGetError())
					return
				}
			}
			sendLifecycle(lifecycle.StageFocused)
			widthPx := int(C.ANativeWindow_getWidth(w))
			heightPx := int(C.ANativeWindow_getHeight(w))
			eventsIn <- config.Event{
				WidthPx:     widthPx,
				HeightPx:    heightPx,
				WidthPt:     geom.Pt(float32(widthPx) / pixelsPerPt),
				HeightPt:    geom.Pt(float32(heightPx) / pixelsPerPt),
				PixelsPerPt: pixelsPerPt,
			}
			redrawGen++
			if newWindow {
				// New window, begin paint loop.
				eventsIn <- paint.Event{redrawGen}
			}
		case <-windowDestroyed:
			if C.surface != nil {
				if errStr := C.destroyEGLSurface(); errStr != nil {
					log.Printf("app: %s (%s)", C.GoString(errStr), eglGetError())
					return
				}
			}
			C.surface = nil
			sendLifecycle(lifecycle.StageAlive)
		case <-gl.WorkAvailable:
			gl.DoWork()
		case p := <-endPaint:
			if p.Generation != redrawGen {
				continue
			}
			if C.surface != nil {
				// eglSwapBuffers blocks until vsync.
				if C.eglSwapBuffers(C.display, C.surface) == C.EGL_FALSE {
					log.Printf("app: failed to swap buffers (%s)", eglGetError())
				}
			}
			select {
			case windowRedrawDone <- struct{}{}:
			default:
			}
			if C.surface != nil {
				redrawGen++
				eventsIn <- paint.Event{redrawGen}
			}
		}
	}
}

func processEvents(queue *C.AInputQueue) {
	var event *C.AInputEvent
	for C.AInputQueue_getEvent(queue, &event) >= 0 {
		if C.AInputQueue_preDispatchEvent(queue, event) != 0 {
			continue
		}
		processEvent(event)
		C.AInputQueue_finishEvent(queue, event, 0)
	}
}

func processEvent(e *C.AInputEvent) {
	switch C.AInputEvent_getType(e) {
	case C.AINPUT_EVENT_TYPE_KEY:
		log.Printf("TODO input event: key")
	case C.AINPUT_EVENT_TYPE_MOTION:
		// At most one of the events in this batch is an up or down event; get its index and change.
		upDownIndex := C.size_t(C.AMotionEvent_getAction(e)&C.AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> C.AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT
		upDownType := touch.TypeMove
		switch C.AMotionEvent_getAction(e) & C.AMOTION_EVENT_ACTION_MASK {
		case C.AMOTION_EVENT_ACTION_DOWN, C.AMOTION_EVENT_ACTION_POINTER_DOWN:
			upDownType = touch.TypeBegin
		case C.AMOTION_EVENT_ACTION_UP, C.AMOTION_EVENT_ACTION_POINTER_UP:
			upDownType = touch.TypeEnd
		}

		for i, n := C.size_t(0), C.AMotionEvent_getPointerCount(e); i < n; i++ {
			t := touch.TypeMove
			if i == upDownIndex {
				t = upDownType
			}
			eventsIn <- touch.Event{
				X:        float32(C.AMotionEvent_getX(e, i)),
				Y:        float32(C.AMotionEvent_getY(e, i)),
				Sequence: touch.Sequence(C.AMotionEvent_getPointerId(e, i)),
				Type:     t,
			}
		}
	default:
		log.Printf("unknown input event, type=%d", C.AInputEvent_getType(e))
	}
}

func eglGetError() string {
	switch errNum := C.eglGetError(); errNum {
	case C.EGL_SUCCESS:
		return "EGL_SUCCESS"
	case C.EGL_NOT_INITIALIZED:
		return "EGL_NOT_INITIALIZED"
	case C.EGL_BAD_ACCESS:
		return "EGL_BAD_ACCESS"
	case C.EGL_BAD_ALLOC:
		return "EGL_BAD_ALLOC"
	case C.EGL_BAD_ATTRIBUTE:
		return "EGL_BAD_ATTRIBUTE"
	case C.EGL_BAD_CONTEXT:
		return "EGL_BAD_CONTEXT"
	case C.EGL_BAD_CONFIG:
		return "EGL_BAD_CONFIG"
	case C.EGL_BAD_CURRENT_SURFACE:
		return "EGL_BAD_CURRENT_SURFACE"
	case C.EGL_BAD_DISPLAY:
		return "EGL_BAD_DISPLAY"
	case C.EGL_BAD_SURFACE:
		return "EGL_BAD_SURFACE"
	case C.EGL_BAD_MATCH:
		return "EGL_BAD_MATCH"
	case C.EGL_BAD_PARAMETER:
		return "EGL_BAD_PARAMETER"
	case C.EGL_BAD_NATIVE_PIXMAP:
		return "EGL_BAD_NATIVE_PIXMAP"
	case C.EGL_BAD_NATIVE_WINDOW:
		return "EGL_BAD_NATIVE_WINDOW"
	case C.EGL_CONTEXT_LOST:
		return "EGL_CONTEXT_LOST"
	default:
		return fmt.Sprintf("Unknown EGL err: %d", errNum)
	}
}
