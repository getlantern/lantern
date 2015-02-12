// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux,!android

#include "_cgo_export.h"
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static Window
new_window(Display *x_dpy, EGLDisplay e_dpy, int w, int h, EGLContext *ctx, EGLSurface *surf) {
	static const EGLint attribs[] = {
		EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
		EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
		EGL_BLUE_SIZE, 8,
		EGL_GREEN_SIZE, 8,
		EGL_RED_SIZE, 8,
		EGL_DEPTH_SIZE, 16,
		EGL_CONFIG_CAVEAT, EGL_NONE,
		EGL_NONE
	};
	EGLConfig config;
	EGLint num_configs;
	if (!eglChooseConfig(e_dpy, attribs, &config, 1, &num_configs)) {
		fprintf(stderr, "eglChooseConfig failed\n");
		exit(1);
	}
	EGLint vid;
	if (!eglGetConfigAttrib(e_dpy, config, EGL_NATIVE_VISUAL_ID, &vid)) {
		fprintf(stderr, "eglGetConfigAttrib failed\n");
		exit(1);
	}

	XVisualInfo visTemplate;
	visTemplate.visualid = vid;
	int num_visuals;
	XVisualInfo *visInfo = XGetVisualInfo(x_dpy, VisualIDMask, &visTemplate, &num_visuals);
	if (!visInfo) {
		fprintf(stderr, "XGetVisualInfo failed\n");
		exit(1);
	}

	Window root = RootWindow(x_dpy, DefaultScreen(x_dpy));
	XSetWindowAttributes attr;
	attr.event_mask = StructureNotifyMask | ExposureMask |
		ButtonPressMask | ButtonReleaseMask | ButtonMotionMask;
	Window win = XCreateWindow(
		x_dpy, root, 0, 0, w, h, 0, visInfo->depth, InputOutput,
		visInfo->visual, CWEventMask, &attr);
	XFree(visInfo);

	XSizeHints sizehints;
	sizehints.width  = w;
	sizehints.height = h;
	sizehints.flags = USSize;
	XSetNormalHints(x_dpy, win, &sizehints);
	XSetStandardProperties(x_dpy, win, "App", "App", None, (char **)NULL, 0, &sizehints);

	static const EGLint ctx_attribs[] = {
		EGL_CONTEXT_CLIENT_VERSION, 2,
		EGL_NONE
	};
	*ctx = eglCreateContext(e_dpy, config, EGL_NO_CONTEXT, ctx_attribs);
	if (!*ctx) {
		fprintf(stderr, "eglCreateContext failed\n");
		exit(1);
	}
	*surf = eglCreateWindowSurface(e_dpy, config, win, NULL);
	if (!*surf) {
		fprintf(stderr, "eglCreateWindowSurface failed\n");
		exit(1);
	}
	return win;
}

void
runApp(void) {
	Display *x_dpy = XOpenDisplay(NULL);
	if (!x_dpy) {
		fprintf(stderr, "XOpenDisplay failed\n");
		exit(1);
	}
	EGLDisplay e_dpy = eglGetDisplay(x_dpy);
	if (!e_dpy) {
		fprintf(stderr, "eglGetDisplay failed\n");
		exit(1);
	}
	EGLint e_major, e_minor;
	if (!eglInitialize(e_dpy, &e_major, &e_minor)) {
		fprintf(stderr, "eglInitialize failed\n");
		exit(1);
	}
	eglBindAPI(EGL_OPENGL_ES_API);
	EGLContext e_ctx;
	EGLSurface e_surf;
	Window win = new_window(x_dpy, e_dpy, 400, 400, &e_ctx, &e_surf);
	XMapWindow(x_dpy, win);
	if (!eglMakeCurrent(e_dpy, e_surf, e_surf, e_ctx)) {
		fprintf(stderr, "eglMakeCurrent failed\n");
		exit(1);
	}

	while (1) {
		XEvent ev;
		XNextEvent(x_dpy, &ev);
		switch (ev.type) {
		case ButtonPress:
			onTouchStart((float)ev.xbutton.x, (float)ev.xbutton.y);
			break;
		case ButtonRelease:
			onTouchEnd((float)ev.xbutton.x, (float)ev.xbutton.y);
			break;
		case MotionNotify:
			onTouchMove((float)ev.xmotion.x, (float)ev.xmotion.y);
			break;
		case Expose:
			onDraw();
			eglSwapBuffers(e_dpy, e_surf);

			// TODO(nigeltao): subscribe to vblank events instead of forcing another
			// expose event to keep the event loop ticking over.
			// TODO(nigeltao): no longer #include <string.h> when we don't use memset.
			XExposeEvent fakeEvent;
			memset(&fakeEvent, 0, sizeof(XExposeEvent));
			fakeEvent.type = Expose;
			fakeEvent.window = win;
			XSendEvent(x_dpy, win, 0, 0, (XEvent*)&fakeEvent);
			XFlush(x_dpy);

			break;
		case ConfigureNotify:
			onResize(ev.xconfigure.width, ev.xconfigure.height);
			glViewport(0, 0, (GLint)ev.xconfigure.width, (GLint)ev.xconfigure.height);
			break;
		}
	}
}
