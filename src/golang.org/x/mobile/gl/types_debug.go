// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin
// +build gldebug

package gl

// Alternate versions of the types defined in types.go with extra
// debugging information attached. For documentation, see types.go.

// #include "work.h"
import "C"
import "fmt"

type Enum uint32

type Attrib struct {
	Value uint
	name  string
}

type Program struct {
	Value uint32
}

type Shader struct {
	Value uint32
}

type Buffer struct {
	Value uint32
}

type Framebuffer struct {
	Value uint32
}

type Renderbuffer struct {
	Value uint32
}

type Texture struct {
	Value uint32
}

type Uniform struct {
	Value int32
	name  string
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

func (v Attrib) String() string       { return fmt.Sprintf("Attrib(%d:%s)", v.Value, v.name) }
func (v Program) String() string      { return fmt.Sprintf("Program(%d)", v.Value) }
func (v Shader) String() string       { return fmt.Sprintf("Shader(%d)", v.Value) }
func (v Buffer) String() string       { return fmt.Sprintf("Buffer(%d)", v.Value) }
func (v Framebuffer) String() string  { return fmt.Sprintf("Framebuffer(%d)", v.Value) }
func (v Renderbuffer) String() string { return fmt.Sprintf("Renderbuffer(%d)", v.Value) }
func (v Texture) String() string      { return fmt.Sprintf("Texture(%d)", v.Value) }
func (v Uniform) String() string      { return fmt.Sprintf("Uniform(%d:%s)", v.Value, v.name) }
