// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin
// +build !gldebug

package gl

// #include "work.h"
import "C"
import "fmt"

// Enum is equivalent to GLenum, and is normally used with one of the
// constants defined in this package.
type Enum uint32

// Types are defined a structs so that in debug mode they can carry
// extra information, such as a string name. See typesdebug.go.

// Attrib identifies the location of a specific attribute variable.
type Attrib struct {
	Value uint
}

// Program identifies a compiled shader program.
type Program struct {
	Value uint32
}

// Shader identifies a GLSL shader.
type Shader struct {
	Value uint32
}

// Buffer identifies a GL buffer object.
type Buffer struct {
	Value uint32
}

// Framebuffer identifies a GL framebuffer.
type Framebuffer struct {
	Value uint32
}

// A Renderbuffer is a GL object that holds an image in an internal format.
type Renderbuffer struct {
	Value uint32
}

// A Texture identifies a GL texture unit.
type Texture struct {
	Value uint32
}

// Uniform identifies the location of a specific uniform variable.
type Uniform struct {
	Value int32
}

func (v Attrib) c() C.uintptr_t       { return C.uintptr_t(v.Value) }
func (v Enum) c() C.uintptr_t         { return C.uintptr_t(v) }
func (v Program) c() C.uintptr_t      { return C.uintptr_t(v.Value) }
func (v Shader) c() C.uintptr_t       { return C.uintptr_t(v.Value) }
func (v Buffer) c() C.uintptr_t       { return C.uintptr_t(v.Value) }
func (v Framebuffer) c() C.uintptr_t  { return C.uintptr_t(v.Value) }
func (v Renderbuffer) c() C.uintptr_t { return C.uintptr_t(v.Value) }
func (v Texture) c() C.uintptr_t      { return C.uintptr_t(v.Value) }
func (v Uniform) c() C.uintptr_t      { return C.uintptr_t(v.Value) }

func (v Attrib) String() string       { return fmt.Sprintf("Attrib(%d)", v.Value) }
func (v Program) String() string      { return fmt.Sprintf("Program(%d)", v.Value) }
func (v Shader) String() string       { return fmt.Sprintf("Shader(%d)", v.Value) }
func (v Buffer) String() string       { return fmt.Sprintf("Buffer(%d)", v.Value) }
func (v Framebuffer) String() string  { return fmt.Sprintf("Framebuffer(%d)", v.Value) }
func (v Renderbuffer) String() string { return fmt.Sprintf("Renderbuffer(%d)", v.Value) }
func (v Texture) String() string      { return fmt.Sprintf("Texture(%d)", v.Value) }
func (v Uniform) String() string      { return fmt.Sprintf("Uniform(%d)", v.Value) }
