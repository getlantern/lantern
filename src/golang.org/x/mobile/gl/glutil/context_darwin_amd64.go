// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin

package glutil

// TODO(crawshaw): Only used in glutil tests for now (cgo is not support in _test.go files).
// TODO(crawshaw): Export some kind of Context. Work out what we can offer, where. Maybe just for tests.
// TODO(crawshaw): Support android and windows.

/*
#cgo LDFLAGS: -framework OpenGL
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>

void CGCreate(CGLContextObj* ctx) {
	CGLPixelFormatAttribute attributes[] = {
		kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
		kCGLPFAColorSize, (CGLPixelFormatAttribute)24,
		kCGLPFAAlphaSize, (CGLPixelFormatAttribute)8,
		kCGLPFADepthSize, (CGLPixelFormatAttribute)16,
		kCGLPFAAccelerated,
		kCGLPFADoubleBuffer,
		(CGLPixelFormatAttribute) 0
	};
	CGLPixelFormatObj pix;
	GLint num;
	CGLChoosePixelFormat(attributes, &pix, &num);
	CGLCreateContext(pix, 0, ctx);
	CGLDestroyPixelFormat(pix);
	CGLSetCurrentContext(*ctx);
	CGLLockContext(*ctx);
}
*/
import "C"

import "runtime"

// contextGL holds a copy of the OpenGL Context from thread-local storage.
//
// Do not move a contextGL between goroutines or OS threads.
type contextGL struct {
	ctx C.CGLContextObj
}

// createContext creates an OpenGL context, binds it as the current context
// stored in thread-local storage, and locks the current goroutine to an os
// thread.
func createContext() *contextGL {
	// The OpenGL active context is stored in TLS.
	runtime.LockOSThread()

	c := new(contextGL)
	C.CGCreate(&c.ctx)

	// Using attribute arrays in OpenGL 3.3 requires the use of a VBA.
	// But VBAs don't exist in ES 2. So we bind a default one.
	var id C.GLuint
	C.glGenVertexArrays(1, &id)
	C.glBindVertexArray(id)

	return c
}

// destroy destroys an OpenGL context and unlocks the current goroutine from
// its os thread.
func (c *contextGL) destroy() {
	C.CGLUnlockContext(c.ctx)
	C.CGLSetCurrentContext(nil)
	C.CGLDestroyContext(c.ctx)
	c.ctx = nil
	runtime.UnlockOSThread()
}
