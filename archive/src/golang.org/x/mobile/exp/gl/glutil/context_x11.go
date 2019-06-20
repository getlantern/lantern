// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux,!android

package glutil

/*
#cgo LDFLAGS: -lEGL
#include <EGL/egl.h>
#include <stdio.h>
#include <stdlib.h>

void createContext(EGLDisplay *out_dpy, EGLContext *out_ctx, EGLSurface *out_surf) {
	EGLDisplay e_dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
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
	static const EGLint config_attribs[] = {
		EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
		EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
		EGL_BLUE_SIZE, 8,
		EGL_GREEN_SIZE, 8,
		EGL_RED_SIZE, 8,
		EGL_CONFIG_CAVEAT, EGL_NONE,
		EGL_NONE
	};
	EGLConfig config;
	EGLint num_configs;
	if (!eglChooseConfig(e_dpy, config_attribs, &config, 1, &num_configs)) {
		fprintf(stderr, "eglChooseConfig failed\n");
		exit(1);
	}
	static const EGLint ctx_attribs[] = {
		EGL_CONTEXT_CLIENT_VERSION, 2,
		EGL_NONE
	};
	EGLContext e_ctx = eglCreateContext(e_dpy, config, EGL_NO_CONTEXT, ctx_attribs);
	if (e_ctx == EGL_NO_CONTEXT) {
		fprintf(stderr, "eglCreateContext failed\n");
		exit(1);
	}
	static const EGLint pbuf_attribs[] = {
		EGL_NONE
	};
	EGLSurface e_surf = eglCreatePbufferSurface(e_dpy, config, pbuf_attribs);
	if (e_surf == EGL_NO_SURFACE) {
		fprintf(stderr, "eglCreatePbufferSurface failed\n");
		exit(1);
	}
	if (!eglMakeCurrent(e_dpy, e_surf, e_surf, e_ctx)) {
		fprintf(stderr, "eglMakeCurrent failed\n");
		exit(1);
	}
	*out_surf = e_surf;
	*out_ctx = e_ctx;
	*out_dpy = e_dpy;
}

void destroyContext(EGLDisplay e_dpy, EGLContext e_ctx, EGLSurface e_surf) {
	if (!eglMakeCurrent(e_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {
		fprintf(stderr, "eglMakeCurrent failed\n");
		exit(1);
	}
	if (!eglDestroySurface(e_dpy, e_surf)) {
		fprintf(stderr, "eglDestroySurface failed\n");
		exit(1);
	}
	if (!eglDestroyContext(e_dpy, e_ctx)) {
		fprintf(stderr, "eglDestroyContext failed\n");
		exit(1);
	}
}
*/
import "C"

import (
	"runtime"
)

type contextGL struct {
	dpy  C.EGLDisplay
	ctx  C.EGLContext
	surf C.EGLSurface
}

func createContext() (*contextGL, error) {
	runtime.LockOSThread()
	c := &contextGL{}
	C.createContext(&c.dpy, &c.ctx, &c.surf)
	return c, nil
}

func (c *contextGL) destroy() {
	C.destroyContext(c.dpy, c.ctx, c.surf)
	runtime.UnlockOSThread()
}
