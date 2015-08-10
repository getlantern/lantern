// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package app

/*
#include <android/log.h>
#include <android/native_activity.h>
#include <android/native_window.h>
#include <android/input.h>
#include <EGL/egl.h>
#include <GLES/gl.h>

// TODO(crawshaw): Test configuration on more devices.
const EGLint RGB_888[] = {
	EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
	EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
	EGL_BLUE_SIZE, 8,
	EGL_GREEN_SIZE, 8,
	EGL_RED_SIZE, 8,
	EGL_DEPTH_SIZE, 16,
	EGL_CONFIG_CAVEAT, EGL_NONE,
	EGL_NONE
};

EGLDisplay display;
EGLSurface surface;

#define LOG_ERROR(...) __android_log_print(ANDROID_LOG_ERROR, "Go", __VA_ARGS__)

void createEGLWindow(ANativeWindow* window) {
	EGLint numConfigs, format;
	EGLConfig config;
	EGLContext context;

	display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
	if (!eglInitialize(display, 0, 0)) {
		LOG_ERROR("EGL initialize failed");
		return;
	}

	if (!eglChooseConfig(display, RGB_888, &config, 1, &numConfigs)) {
		LOG_ERROR("EGL choose RGB_888 config failed");
		return;
	}
	if (numConfigs <= 0) {
		LOG_ERROR("EGL no config found");
		return;
	}

	eglGetConfigAttrib(display, config, EGL_NATIVE_VISUAL_ID, &format);
	if (ANativeWindow_setBuffersGeometry(window, 0, 0, format) != 0) {
		LOG_ERROR("EGL set buffers geometry failed");
		return;
	}

	surface = eglCreateWindowSurface(display, config, window, NULL);
	if (surface == EGL_NO_SURFACE) {
		LOG_ERROR("EGL create surface failed");
		return;
	}

	const EGLint contextAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
	context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);

	if (eglMakeCurrent(display, surface, surface, context) == EGL_FALSE) {
		LOG_ERROR("eglMakeCurrent failed");
		return;
	}
}

#undef LOG_ERROR
*/
import "C"
import (
	"log"

	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/event/paint"
	"golang.org/x/mobile/event/touch"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

func windowDraw(w *C.ANativeWindow, queue *C.AInputQueue, donec chan struct{}) (done bool) {
	// Android can send a windowRedrawNeeded event any time, including
	// in the middle of a paint cycle. The redraw event may have changed
	// the size of the screen, so any partial painting is now invalidated.
	// We must also not return to Android (via sending on windowRedrawDone)
	// until a complete paint with the new configuration is complete.
	//
	// When a windowRedrawNeeded request comes in, we increment redrawGen
	// (Gen is short for generation number), and do not make a paint cycle
	// visible on <-endPaint unless paintGen agrees. If possible,
	// windowRedrawDone is signalled, allowing onNativeWindowRedrawNeeded
	// to return.
	var redrawGen, paintGen uint32
	for {
		processEvents(queue)
		select {
		case <-donec:
			return true
		case cfg := <-windowConfigChange:
			// TODO save orientation
			pixelsPerPt = cfg.pixelsPerPt
		case w := <-windowRedrawNeeded:
			sendLifecycle(lifecycle.StageFocused)
			eventsIn <- config.Event{
				Width:       geom.Pt(float32(C.ANativeWindow_getWidth(w)) / pixelsPerPt),
				Height:      geom.Pt(float32(C.ANativeWindow_getHeight(w)) / pixelsPerPt),
				PixelsPerPt: pixelsPerPt,
			}
			if paintGen == 0 {
				paintGen++
				C.createEGLWindow(w)
				eventsIn <- paint.Event{}
			}
			redrawGen++
		case <-windowDestroyed:
			sendLifecycle(lifecycle.StageAlive)
			return false
		case <-gl.WorkAvailable:
			gl.DoWork()
		case <-endPaint:
			if paintGen == redrawGen {
				// eglSwapBuffers blocks until vsync.
				C.eglSwapBuffers(C.display, C.surface)
				select {
				case windowRedrawDone <- struct{}{}:
				default:
				}
			}
			paintGen = redrawGen
			eventsIn <- paint.Event{}
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
				Sequence: touch.Sequence(C.AMotionEvent_getPointerId(e, i)),
				Type:     t,
				Loc: geom.Point{
					X: geom.Pt(float32(C.AMotionEvent_getX(e, i)) / pixelsPerPt),
					Y: geom.Pt(float32(C.AMotionEvent_getY(e, i)) / pixelsPerPt),
				},
			}
		}
	default:
		log.Printf("unknown input event, type=%d", C.AInputEvent_getType(e))
	}
}
