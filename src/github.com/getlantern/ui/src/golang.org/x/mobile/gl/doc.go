// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
Package gl implements Go bindings for OpenGL ES 2.

The bindings are deliberately minimal, staying as close the C API as
possible. The semantics of each function maps onto functions
described in the Khronos documentation:

https://www.khronos.org/opengles/sdk/docs/man/

One notable departure from the C API is the introduction of types
to represent common uses of GLint: Texture, Surface, Buffer, etc.

A tracing version of the OpenGL bindings is behind the `gldebug` build
tag. It acts as a simplified version of apitrace. Build your Go binary
with

	-tags gldebug

and each call to a GL function will log its input, output, and any
error messages. For example,

	I/GoLog   (27668): gl.GenBuffers(1) [Buffer(70001)]
	I/GoLog   (27668): gl.BindBuffer(ARRAY_BUFFER, Buffer(70001))
	I/GoLog   (27668): gl.BufferData(ARRAY_BUFFER, 36, len(36), STATIC_DRAW)
	I/GoLog   (27668): gl.BindBuffer(ARRAY_BUFFER, Buffer(70001))
	I/GoLog   (27668): gl.VertexAttribPointer(Attrib(0), 6, FLOAT, false, 0, 0)  error: [INVALID_VALUE]

The gldebug tracing has very high overhead, so make sure to remove
the build tag before deploying any binaries.
*/
package gl // import "golang.org/x/mobile/gl"

//go:generate go run gendebug.go -o gldebug.go
