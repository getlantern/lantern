// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin

package gl

// This file contains GL Types and their methods that are independent of the
// "gldebug" build tag.

/*
#cgo darwin,amd64  LDFLAGS: -framework OpenGL
#cgo darwin,arm    LDFLAGS: -framework OpenGLES
#cgo linux         LDFLAGS: -lGLESv2

#cgo darwin,amd64  CFLAGS: -Dos_darwin_amd64
#cgo darwin,arm    CFLAGS: -Dos_darwin_arm
#cgo linux         CFLAGS: -Dos_linux

#ifdef os_linux
#include <GLES2/gl2.h>
#endif
#ifdef os_darwin_arm
#include <OpenGLES/ES2/gl.h>
#endif
#ifdef os_darwin_amd64
#include <OpenGL/gl3.h>
#endif

void blendColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a) { glBlendColor(r, g, b, a); }
void clearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a) { glClearColor(r, g, b, a); }
void clearDepthf(GLfloat d)                                 { glClearDepthf(d); }
void depthRangef(GLfloat n, GLfloat f)                      { glDepthRangef(n, f); }
void sampleCoverage(GLfloat v, GLboolean invert)            { glSampleCoverage(v, invert); }
*/
import "C"
import "golang.org/x/mobile/f32"

// WriteAffine writes the contents of an Affine to a 3x3 matrix GL uniform.
func (u Uniform) WriteAffine(a *f32.Affine) {
	var m [9]float32
	m[0*3+0] = a[0][0]
	m[0*3+1] = a[1][0]
	m[0*3+2] = 0
	m[1*3+0] = a[0][1]
	m[1*3+1] = a[1][1]
	m[1*3+2] = 0
	m[2*3+0] = a[0][2]
	m[2*3+1] = a[1][2]
	m[2*3+2] = 1
	UniformMatrix3fv(u, m[:])
}

// WriteMat4 writes the contents of a 4x4 matrix to a GL uniform.
func (u Uniform) WriteMat4(p *f32.Mat4) {
	var m [16]float32
	m[0*4+0] = p[0][0]
	m[0*4+1] = p[1][0]
	m[0*4+2] = p[2][0]
	m[0*4+3] = p[3][0]
	m[1*4+0] = p[0][1]
	m[1*4+1] = p[1][1]
	m[1*4+2] = p[2][1]
	m[1*4+3] = p[3][1]
	m[2*4+0] = p[0][2]
	m[2*4+1] = p[1][2]
	m[2*4+2] = p[2][2]
	m[2*4+3] = p[3][2]
	m[3*4+0] = p[0][3]
	m[3*4+1] = p[1][3]
	m[3*4+2] = p[2][3]
	m[3*4+3] = p[3][3]
	UniformMatrix4fv(u, m[:])
}

// WriteVec4 writes the contents of a 4-element vector to a GL uniform.
func (u Uniform) WriteVec4(v *f32.Vec4) {
	Uniform4f(u, v[0], v[1], v[2], v[3])
}

func glBoolean(b bool) C.GLboolean {
	if b {
		return TRUE
	}
	return FALSE
}

// Desktop OpenGL and the ES 2/3 APIs have a very slight difference
// that is imperceptible to C programmers: some function parameters
// use the type Glclampf and some use GLfloat. These two types are
// equivalent in size and bit layout (both are single-precision
// floats), but it plays havoc with cgo. We adjust the types by using
// C wrappers for the problematic functions.

func blendColor(r, g, b, a float32) {
	C.blendColor(C.GLfloat(r), C.GLfloat(g), C.GLfloat(b), C.GLfloat(a))
}
func clearColor(r, g, b, a float32) {
	C.clearColor(C.GLfloat(r), C.GLfloat(g), C.GLfloat(b), C.GLfloat(a))
}
func clearDepthf(d float32)            { C.clearDepthf(C.GLfloat(d)) }
func depthRangef(n, f float32)         { C.depthRangef(C.GLfloat(n), C.GLfloat(f)) }
func sampleCoverage(v float32, i bool) { C.sampleCoverage(C.GLfloat(v), glBoolean(i)) }
