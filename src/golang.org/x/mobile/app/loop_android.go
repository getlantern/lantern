// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package app

/*
#cgo android LDFLAGS: -llog -landroid -lEGL -lGLESv2
#include <android/log.h>
#include <android/native_activity.h>
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

EGLint windowWidth;
EGLint windowHeight;
EGLDisplay display;
EGLSurface surface;

#define LOG_ERROR(...) __android_log_print(ANDROID_LOG_ERROR, "Go", __VA_ARGS__)

void querySurfaceWidthAndHeight() {
	eglQuerySurface(display, surface, EGL_WIDTH, &windowWidth);
	eglQuerySurface(display, surface, EGL_HEIGHT, &windowHeight);
}

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

	querySurfaceWidthAndHeight();
}

#undef LOG_ERROR
*/
import "C"
import (
	"log"

	"golang.org/x/mobile/event"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

func windowDraw(callbacks []Callbacks, w *C.ANativeWindow, queue *C.AInputQueue) {
	C.createEGLWindow(w)

	// TODO: is the library or the app responsible for clearing the buffers?
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	C.eglSwapBuffers(C.display, C.surface)

	if errv := gl.GetError(); errv != gl.NO_ERROR {
		log.Printf("GL initialization error: %s", errv)
	}

	configAlt.Width = geom.Pt(float32(C.windowWidth) / geom.PixelsPerPt)
	configAlt.Height = geom.Pt(float32(C.windowHeight) / geom.PixelsPerPt)
	configSwap(callbacks)

	// Wait until geometry and GL is initialized before cb.Start.
	stateStart(callbacks)

	for {
		processEvents(callbacks, queue)
		select {
		case <-windowRedrawNeeded:
			// Re-query the width and height.
			C.querySurfaceWidthAndHeight()
			configAlt.Width = geom.Pt(float32(C.windowWidth) / geom.PixelsPerPt)
			configAlt.Height = geom.Pt(float32(C.windowHeight) / geom.PixelsPerPt)
			gl.Viewport(0, 0, int(C.windowWidth), int(C.windowHeight))
			configSwap(callbacks)
		case <-windowDestroyed:
			stateStop(callbacks)
			return
		default:
			for _, cb := range callbacks {
				if cb.Draw != nil {
					cb.Draw()
				}
			}
			C.eglSwapBuffers(C.display, C.surface)
		}
	}
}

func processEvents(callbacks []Callbacks, queue *C.AInputQueue) {
	var event *C.AInputEvent
	for C.AInputQueue_getEvent(queue, &event) >= 0 {
		if C.AInputQueue_preDispatchEvent(queue, event) != 0 {
			continue
		}
		processEvent(callbacks, event)
		C.AInputQueue_finishEvent(queue, event, 0)
	}
}

func processEvent(callbacks []Callbacks, e *C.AInputEvent) {
	switch C.AInputEvent_getType(e) {
	case C.AINPUT_EVENT_TYPE_KEY:
		log.Printf("TODO input event: key")
	case C.AINPUT_EVENT_TYPE_MOTION:
		// TODO: calculate hasTouch once in run
		hasTouch := false
		for _, cb := range callbacks {
			if cb.Touch != nil {
				hasTouch = true
			}
		}
		if !hasTouch {
			return
		}

		// At most one of the events in this batch is an up or down event; get its index and type.
		upDownIndex := C.size_t(C.AMotionEvent_getAction(e)&C.AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> C.AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT
		upDownTyp := event.TouchMove
		switch C.AMotionEvent_getAction(e) & C.AMOTION_EVENT_ACTION_MASK {
		case C.AMOTION_EVENT_ACTION_DOWN, C.AMOTION_EVENT_ACTION_POINTER_DOWN:
			upDownTyp = event.TouchStart
		case C.AMOTION_EVENT_ACTION_UP, C.AMOTION_EVENT_ACTION_POINTER_UP:
			upDownTyp = event.TouchEnd
		}

		for i, n := C.size_t(0), C.AMotionEvent_getPointerCount(e); i < n; i++ {
			typ := event.TouchMove
			if i == upDownIndex {
				typ = upDownTyp
			}
			t := event.Touch{
				ID:   event.TouchSequenceID(C.AMotionEvent_getPointerId(e, i)),
				Type: typ,
				Loc: geom.Point{
					X: geom.Pt(float32(C.AMotionEvent_getX(e, i)) / geom.PixelsPerPt),
					Y: geom.Pt(float32(C.AMotionEvent_getY(e, i)) / geom.PixelsPerPt),
				},
			}
			for _, cb := range callbacks {
				if cb.Touch != nil {
					cb.Touch(t)
				}
			}
		}
	default:
		log.Printf("unknown input event, type=%d", C.AInputEvent_getType(e))
	}
}
