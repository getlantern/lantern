// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin
// +build !gldebug

package gl

// TODO(crawshaw): build on more host platforms (makes it easier to gobind).
// TODO(crawshaw): expand to cover OpenGL ES 3.
// TODO(crawshaw): should functions on specific types become methods? E.g.
//                 	func (t Texture) Bind(target Enum)
//                 this seems natural in Go, but moves us slightly
//                 further away from the underlying OpenGL spec.

// #include "work.h"
import "C"

import (
	"math"
	"unsafe"
)

// ActiveTexture sets the active texture unit.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glActiveTexture.xhtml
func ActiveTexture(texture Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnActiveTexture,
			a0: texture.c(),
		},
	})
}

// AttachShader attaches a shader to a program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glAttachShader.xhtml
func AttachShader(p Program, s Shader) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnAttachShader,
			a0: p.c(),
			a1: s.c(),
		},
	})
}

// BindAttribLocation binds a vertex attribute index with a named
// variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindAttribLocation.xhtml
func BindAttribLocation(p Program, a Attrib, name string) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBindAttribLocation,
			a0: p.c(),
			a1: a.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(C.CString(name)))),
		},
	})
}

// BindBuffer binds a buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindBuffer.xhtml
func BindBuffer(target Enum, b Buffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBindBuffer,
			a0: target.c(),
			a1: b.c(),
		},
	})
}

// BindFramebuffer binds a framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindFramebuffer.xhtml
func BindFramebuffer(target Enum, fb Framebuffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBindFramebuffer,
			a0: target.c(),
			a1: fb.c(),
		},
	})
}

// BindRenderbuffer binds a render buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindRenderbuffer.xhtml
func BindRenderbuffer(target Enum, rb Renderbuffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBindRenderbuffer,
			a0: target.c(),
			a1: rb.c(),
		},
	})
}

// BindTexture binds a texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindTexture.xhtml
func BindTexture(target Enum, t Texture) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBindTexture,
			a0: target.c(),
			a1: t.c(),
		},
	})
}

// BlendColor sets the blend color.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendColor.xhtml
func BlendColor(red, green, blue, alpha float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBlendColor,
			a0: C.uintptr_t(math.Float32bits(red)),
			a1: C.uintptr_t(math.Float32bits(green)),
			a2: C.uintptr_t(math.Float32bits(blue)),
			a3: C.uintptr_t(math.Float32bits(alpha)),
		},
	})
}

// BlendEquation sets both RGB and alpha blend equations.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendEquation.xhtml
func BlendEquation(mode Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBlendEquation,
			a0: mode.c(),
		},
	})
}

// BlendEquationSeparate sets RGB and alpha blend equations separately.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendEquationSeparate.xhtml
func BlendEquationSeparate(modeRGB, modeAlpha Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBlendEquationSeparate,
			a0: modeRGB.c(),
			a1: modeAlpha.c(),
		},
	})
}

// BlendFunc sets the pixel blending factors.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendFunc.xhtml
func BlendFunc(sfactor, dfactor Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBlendFunc,
			a0: sfactor.c(),
			a1: dfactor.c(),
		},
	})
}

// BlendFunc sets the pixel RGB and alpha blending factors separately.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendFuncSeparate.xhtml
func BlendFuncSeparate(sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBlendFuncSeparate,
			a0: sfactorRGB.c(),
			a1: dfactorRGB.c(),
			a2: sfactorAlpha.c(),
			a3: dfactorAlpha.c(),
		},
	})
}

// BufferData creates a new data store for the bound buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBufferData.xhtml
func BufferData(target Enum, src []byte, usage Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBufferData,
			a0: target.c(),
			a1: C.uintptr_t(len(src)),
			a2: (C.uintptr_t)(uintptr(unsafe.Pointer(&src[0]))),
			a3: usage.c(),
		},
		blocking: true,
	})
}

// BufferInit creates a new uninitialized data store for the bound buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBufferData.xhtml
func BufferInit(target Enum, size int, usage Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBufferData,
			a0: target.c(),
			a1: C.uintptr_t(size),
			a2: 0,
			a3: usage.c(),
		},
	})
}

// BufferSubData sets some of data in the bound buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBufferSubData.xhtml
func BufferSubData(target Enum, offset int, data []byte) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnBufferSubData,
			a0: target.c(),
			a1: C.uintptr_t(offset),
			a2: C.uintptr_t(len(data)),
			a3: (C.uintptr_t)(uintptr(unsafe.Pointer(&data[0]))),
		},
		blocking: true,
	})
}

// CheckFramebufferStatus reports the completeness status of the
// active framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCheckFramebufferStatus.xhtml
func CheckFramebufferStatus(target Enum) Enum {
	return Enum(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCheckFramebufferStatus,
			a0: target.c(),
		},
		blocking: true,
	}))
}

// Clear clears the window.
//
// The behavior of Clear is influenced by the pixel ownership test,
// the scissor test, dithering, and the buffer writemasks.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClear.xhtml
func Clear(mask Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnClear,
			a0: C.uintptr_t(mask),
		},
	})
}

// ClearColor specifies the RGBA values used to clear color buffers.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClearColor.xhtml
func ClearColor(red, green, blue, alpha float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnClearColor,
			a0: C.uintptr_t(math.Float32bits(red)),
			a1: C.uintptr_t(math.Float32bits(green)),
			a2: C.uintptr_t(math.Float32bits(blue)),
			a3: C.uintptr_t(math.Float32bits(alpha)),
		},
	})
}

// ClearDepthf sets the depth value used to clear the depth buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClearDepthf.xhtml
func ClearDepthf(d float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnClearDepthf,
			a0: C.uintptr_t(math.Float32bits(d)),
		},
	})
}

// ClearStencil sets the index used to clear the stencil buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClearStencil.xhtml
func ClearStencil(s int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnClearStencil,
			a0: C.uintptr_t(s),
		},
	})
}

// ColorMask specifies whether color components in the framebuffer
// can be written.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glColorMask.xhtml
func ColorMask(red, green, blue, alpha bool) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnColorMask,
			a0: glBoolean(red),
			a1: glBoolean(green),
			a2: glBoolean(blue),
			a3: glBoolean(alpha),
		},
	})
}

// CompileShader compiles the source code of s.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCompileShader.xhtml
func CompileShader(s Shader) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCompileShader,
			a0: s.c(),
		},
	})
}

// CompressedTexImage2D writes a compressed 2D texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCompressedTexImage2D.xhtml
func CompressedTexImage2D(target Enum, level int, internalformat Enum, width, height, border int, data []byte) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCompressedTexImage2D,
			a0: target.c(),
			a1: C.uintptr_t(level),
			a2: internalformat.c(),
			a3: C.uintptr_t(width),
			a4: C.uintptr_t(height),
			a5: C.uintptr_t(border),
			a6: C.uintptr_t(len(data)),
			a7: C.uintptr_t(uintptr(unsafe.Pointer(&data[0]))),
		},
		blocking: true,
	})
}

// CompressedTexSubImage2D writes a subregion of a compressed 2D texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCompressedTexSubImage2D.xhtml
func CompressedTexSubImage2D(target Enum, level, xoffset, yoffset, width, height int, format Enum, data []byte) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCompressedTexSubImage2D,
			a0: target.c(),
			a1: C.uintptr_t(level),
			a2: C.uintptr_t(xoffset),
			a3: C.uintptr_t(yoffset),
			a4: C.uintptr_t(width),
			a5: C.uintptr_t(height),
			a6: format.c(),
			a7: C.uintptr_t(len(data)),
			a8: C.uintptr_t(uintptr(unsafe.Pointer(&data[0]))),
		},
		blocking: true,
	})
}

// CopyTexImage2D writes a 2D texture from the current framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCopyTexImage2D.xhtml
func CopyTexImage2D(target Enum, level int, internalformat Enum, x, y, width, height, border int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCopyTexImage2D,
			a0: target.c(),
			a1: C.uintptr_t(level),
			a2: internalformat.c(),
			a3: C.uintptr_t(x),
			a4: C.uintptr_t(y),
			a5: C.uintptr_t(width),
			a6: C.uintptr_t(height),
			a7: C.uintptr_t(border),
		},
	})
}

// CopyTexSubImage2D writes a 2D texture subregion from the
// current framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCopyTexSubImage2D.xhtml
func CopyTexSubImage2D(target Enum, level, xoffset, yoffset, x, y, width, height int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCopyTexSubImage2D,
			a0: target.c(),
			a1: C.uintptr_t(level),
			a2: C.uintptr_t(xoffset),
			a3: C.uintptr_t(yoffset),
			a4: C.uintptr_t(x),
			a5: C.uintptr_t(y),
			a6: C.uintptr_t(width),
			a7: C.uintptr_t(height),
		},
	})
}

// CreateBuffer creates a buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenBuffers.xhtml
func CreateBuffer() Buffer {
	return Buffer{Value: uint32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGenBuffer,
		},
		blocking: true,
	}))}
}

// CreateFramebuffer creates a framebuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenFramebuffers.xhtml
func CreateFramebuffer() Framebuffer {
	return Framebuffer{Value: uint32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGenFramebuffer,
		},
		blocking: true,
	}))}
}

// CreateProgram creates a new empty program object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCreateProgram.xhtml
func CreateProgram() Program {
	return Program{Value: uint32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCreateProgram,
		},
		blocking: true,
	}))}
}

// CreateRenderbuffer create a renderbuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenRenderbuffers.xhtml
func CreateRenderbuffer() Renderbuffer {
	return Renderbuffer{Value: uint32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGenRenderbuffer,
		},
		blocking: true,
	}))}
}

// CreateShader creates a new empty shader object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCreateShader.xhtml
func CreateShader(ty Enum) Shader {
	return Shader{Value: uint32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCreateShader,
			a0: C.uintptr_t(ty),
		},
		blocking: true,
	}))}
}

// CreateTexture creates a texture object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenTextures.xhtml
func CreateTexture() Texture {
	return Texture{Value: uint32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGenTexture,
		},
		blocking: true,
	}))}
}

// CullFace specifies which polygons are candidates for culling.
//
// Valid modes: FRONT, BACK, FRONT_AND_BACK.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCullFace.xhtml
func CullFace(mode Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnCullFace,
			a0: mode.c(),
		},
	})
}

// DeleteBuffer deletes the given buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteBuffers.xhtml
func DeleteBuffer(v Buffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDeleteBuffer,
			a0: C.uintptr_t(v.Value),
		},
	})
}

// DeleteFramebuffer deletes the given framebuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteFramebuffers.xhtml
func DeleteFramebuffer(v Framebuffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDeleteFramebuffer,
			a0: C.uintptr_t(v.Value),
		},
	})
}

// DeleteProgram deletes the given program object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteProgram.xhtml
func DeleteProgram(p Program) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDeleteProgram,
			a0: p.c(),
		},
	})
}

// DeleteRenderbuffer deletes the given render buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteRenderbuffers.xhtml
func DeleteRenderbuffer(v Renderbuffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDeleteRenderbuffer,
			a0: v.c(),
		},
	})
}

// DeleteShader deletes shader s.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteShader.xhtml
func DeleteShader(s Shader) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDeleteShader,
			a0: s.c(),
		},
	})
}

// DeleteTexture deletes the given texture object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteTextures.xhtml
func DeleteTexture(v Texture) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDeleteTexture,
			a0: v.c(),
		},
	})
}

// DepthFunc sets the function used for depth buffer comparisons.
//
// Valid fn values:
//	NEVER
//	LESS
//	EQUAL
//	LEQUAL
//	GREATER
//	NOTEQUAL
//	GEQUAL
//	ALWAYS
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDepthFunc.xhtml
func DepthFunc(fn Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDepthFunc,
			a0: fn.c(),
		},
	})
}

// DepthMask sets the depth buffer enabled for writing.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDepthMask.xhtml
func DepthMask(flag bool) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDepthMask,
			a0: glBoolean(flag),
		},
	})
}

// DepthRangef sets the mapping from normalized device coordinates to
// window coordinates.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDepthRangef.xhtml
func DepthRangef(n, f float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDepthRangef,
			a0: C.uintptr_t(math.Float32bits(n)),
			a1: C.uintptr_t(math.Float32bits(f)),
		},
	})
}

// DetachShader detaches the shader s from the program p.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDetachShader.xhtml
func DetachShader(p Program, s Shader) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDetachShader,
			a0: p.c(),
			a1: s.c(),
		},
	})
}

// Disable disables various GL capabilities.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDisable.xhtml
func Disable(cap Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDisable,
			a0: cap.c(),
		},
	})
}

// DisableVertexAttribArray disables a vertex attribute array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDisableVertexAttribArray.xhtml
func DisableVertexAttribArray(a Attrib) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDisableVertexAttribArray,
			a0: a.c(),
		},
	})
}

// DrawArrays renders geometric primitives from the bound data.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDrawArrays.xhtml
func DrawArrays(mode Enum, first, count int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDrawArrays,
			a0: mode.c(),
			a1: C.uintptr_t(first),
			a2: C.uintptr_t(count),
		},
	})
}

// DrawElements renders primitives from a bound buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDrawElements.xhtml
func DrawElements(mode Enum, count int, ty Enum, offset int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnDrawElements,
			a0: mode.c(),
			a1: C.uintptr_t(count),
			a2: ty.c(),
			a3: C.uintptr_t(offset),
		},
	})
}

// TODO(crawshaw): consider DrawElements8 / DrawElements16 / DrawElements32

// Enable enables various GL capabilities.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glEnable.xhtml
func Enable(cap Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnEnable,
			a0: cap.c(),
		},
	})
}

// EnableVertexAttribArray enables a vertex attribute array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glEnableVertexAttribArray.xhtml
func EnableVertexAttribArray(a Attrib) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnEnableVertexAttribArray,
			a0: a.c(),
		},
	})
}

// Finish blocks until the effects of all previously called GL
// commands are complete.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFinish.xhtml
func Finish() {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnFinish,
		},
		blocking: true,
	})
}

// Flush empties all buffers. It does not block.
//
// An OpenGL implementation may buffer network communication,
// the command stream, or data inside the graphics accelerator.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFlush.xhtml
func Flush() {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnFlush,
		},
		blocking: true,
	})
}

// FramebufferRenderbuffer attaches rb to the current frame buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFramebufferRenderbuffer.xhtml
func FramebufferRenderbuffer(target, attachment, rbTarget Enum, rb Renderbuffer) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnFramebufferRenderbuffer,
			a0: target.c(),
			a1: attachment.c(),
			a2: rbTarget.c(),
			a3: rb.c(),
		},
	})
}

// FramebufferTexture2D attaches the t to the current frame buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFramebufferTexture2D.xhtml
func FramebufferTexture2D(target, attachment, texTarget Enum, t Texture, level int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnFramebufferTexture2D,
			a0: target.c(),
			a1: attachment.c(),
			a2: texTarget.c(),
			a3: t.c(),
			a4: C.uintptr_t(level),
		},
	})
}

// FrontFace defines which polygons are front-facing.
//
// Valid modes: CW, CCW.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFrontFace.xhtml
func FrontFace(mode Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnFrontFace,
			a0: mode.c(),
		},
	})
}

// GenerateMipmap generates mipmaps for the current texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenerateMipmap.xhtml
func GenerateMipmap(target Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGenerateMipmap,
			a0: target.c(),
		},
	})
}

// GetActiveAttrib returns details about an active attribute variable.
// A value of 0 for index selects the first active attribute variable.
// Permissible values for index range from 0 to the number of active
// attribute variables minus 1.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetActiveAttrib.xhtml
func GetActiveAttrib(p Program, index uint32) (name string, size int, ty Enum) {
	bufSize := GetProgrami(p, ACTIVE_ATTRIBUTE_MAX_LENGTH)
	buf := C.malloc(C.size_t(bufSize))
	defer C.free(buf)
	var cSize C.GLint
	var cType C.GLenum

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetActiveAttrib,
			a0: p.c(),
			a1: C.uintptr_t(index),
			a2: C.uintptr_t(bufSize),
			a3: 0,
			a4: C.uintptr_t(uintptr(unsafe.Pointer(&cSize))),
			a5: C.uintptr_t(uintptr(unsafe.Pointer(&cType))),
			a6: C.uintptr_t(uintptr(unsafe.Pointer(buf))),
		},
		blocking: true,
	})

	return C.GoString((*C.char)(buf)), int(cSize), Enum(cType)
}

// GetActiveUniform returns details about an active uniform variable.
// A value of 0 for index selects the first active uniform variable.
// Permissible values for index range from 0 to the number of active
// uniform variables minus 1.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetActiveUniform.xhtml
func GetActiveUniform(p Program, index uint32) (name string, size int, ty Enum) {
	bufSize := GetProgrami(p, ACTIVE_UNIFORM_MAX_LENGTH)
	buf := C.malloc(C.size_t(bufSize))
	defer C.free(buf)
	var cSize C.GLint
	var cType C.GLenum

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetActiveUniform,
			a0: p.c(),
			a1: C.uintptr_t(index),
			a2: C.uintptr_t(bufSize),
			a3: 0,
			a4: C.uintptr_t(uintptr(unsafe.Pointer(&cSize))),
			a5: C.uintptr_t(uintptr(unsafe.Pointer(&cType))),
			a6: C.uintptr_t(uintptr(unsafe.Pointer(buf))),
		},
		blocking: true,
	})

	return C.GoString((*C.char)(buf)), int(cSize), Enum(cType)
}

// GetAttachedShaders returns the shader objects attached to program p.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetAttachedShaders.xhtml
func GetAttachedShaders(p Program) []Shader {
	shadersLen := GetProgrami(p, ATTACHED_SHADERS)
	var n C.GLsizei
	buf := make([]C.GLuint, shadersLen)

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetAttachedShaders,
			a0: p.c(),
			a1: C.uintptr_t(shadersLen),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&n))),
			a3: C.uintptr_t(uintptr(unsafe.Pointer(&buf[0]))),
		},
		blocking: true,
	})

	buf = buf[:int(n)]
	shaders := make([]Shader, len(buf))
	for i, s := range buf {
		shaders[i] = Shader{Value: uint32(s)}
	}
	return shaders
}

// GetAttribLocation returns the location of an attribute variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetAttribLocation.xhtml
func GetAttribLocation(p Program, name string) Attrib {
	return Attrib{Value: uint(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetAttribLocation,
			a0: p.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(C.CString(name)))),
		},
		blocking: true,
	}))}
}

// GetBooleanv returns the boolean values of parameter pname.
//
// Many boolean parameters can be queried more easily using IsEnabled.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetBooleanv(dst []bool, pname Enum) {
	buf := make([]C.GLboolean, len(dst))

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetBooleanv,
			a0: pname.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&buf[0]))),
		},
		blocking: true,
	})

	for i, v := range buf {
		dst[i] = v != 0
	}
}

// GetFloatv returns the float values of parameter pname.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetFloatv(dst []float32, pname Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetFloatv,
			a0: pname.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// GetIntegerv returns the int values of parameter pname.
//
// Single values may be queried more easily using GetInteger.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetIntegerv(dst []int32, pname Enum) {
	buf := make([]C.GLint, len(dst))

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetIntegerv,
			a0: pname.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&buf[0]))),
		},
		blocking: true,
	})

	for i, v := range buf {
		dst[i] = int32(v)
	}
}

// GetInteger returns the int value of parameter pname.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetInteger(pname Enum) int {
	var v [1]int32
	GetIntegerv(v[:], pname)
	return int(v[0])
}

// GetBufferParameteri returns a parameter for the active buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetBufferParameter.xhtml
func GetBufferParameteri(target, value Enum) int {
	return int(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetBufferParameteri,
			a0: target.c(),
			a1: value.c(),
		},
		blocking: true,
	}))
}

// GetError returns the next error.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetError.xhtml
func GetError() Enum {
	return Enum(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetError,
		},
		blocking: true,
	}))
}

// GetFramebufferAttachmentParameteri returns attachment parameters
// for the active framebuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetFramebufferAttachmentParameteriv.xhtml
func GetFramebufferAttachmentParameteri(target, attachment, pname Enum) int {
	return int(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetFramebufferAttachmentParameteriv,
			a0: target.c(),
			a1: attachment.c(),
			a2: pname.c(),
		},
		blocking: true,
	}))
}

// GetProgrami returns a parameter value for a program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetProgramiv.xhtml
func GetProgrami(p Program, pname Enum) int {
	return int(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetProgramiv,
			a0: p.c(),
			a1: pname.c(),
		},
		blocking: true,
	}))
}

// GetProgramInfoLog returns the information log for a program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetProgramInfoLog.xhtml
func GetProgramInfoLog(p Program) string {
	infoLen := GetProgrami(p, INFO_LOG_LENGTH)
	buf := C.malloc(C.size_t(infoLen))
	defer C.free(buf)

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetProgramInfoLog,
			a0: p.c(),
			a1: C.uintptr_t(infoLen),
			a2: 0,
			a3: C.uintptr_t(uintptr(buf)),
		},
		blocking: true,
	})

	return C.GoString((*C.char)(buf))
}

// GetRenderbufferParameteri returns a parameter value for a render buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetRenderbufferParameteriv.xhtml
func GetRenderbufferParameteri(target, pname Enum) int {
	return int(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetRenderbufferParameteriv,
			a0: target.c(),
			a1: pname.c(),
		},
		blocking: true,
	}))
}

// GetShaderi returns a parameter value for a shader.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderiv.xhtml
func GetShaderi(s Shader, pname Enum) int {
	return int(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetShaderiv,
			a0: s.c(),
			a1: pname.c(),
		},
		blocking: true,
	}))
}

// GetShaderInfoLog returns the information log for a shader.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderInfoLog.xhtml
func GetShaderInfoLog(s Shader) string {
	infoLen := GetShaderi(s, INFO_LOG_LENGTH)
	buf := C.malloc(C.size_t(infoLen))
	defer C.free(buf)

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetShaderInfoLog,
			a0: s.c(),
			a1: C.uintptr_t(infoLen),
			a2: 0,
			a3: C.uintptr_t(uintptr(buf)),
		},
		blocking: true,
	})

	return C.GoString((*C.char)(buf))
}

// GetShaderPrecisionFormat returns range and precision limits for
// shader types.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderPrecisionFormat.xhtml
func GetShaderPrecisionFormat(shadertype, precisiontype Enum) (rangeLow, rangeHigh, precision int) {
	var cRange [2]C.GLint
	var cPrecision C.GLint

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetShaderPrecisionFormat,
			a0: shadertype.c(),
			a1: precisiontype.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&cRange[0]))),
			a3: C.uintptr_t(uintptr(unsafe.Pointer(&cPrecision))),
		},
		blocking: true,
	})

	return int(cRange[0]), int(cRange[1]), int(cPrecision)
}

// GetShaderSource returns source code of shader s.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderSource.xhtml
func GetShaderSource(s Shader) string {
	sourceLen := GetShaderi(s, SHADER_SOURCE_LENGTH)
	if sourceLen == 0 {
		return ""
	}
	buf := C.malloc(C.size_t(sourceLen))
	defer C.free(buf)

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetShaderSource,
			a0: s.c(),
			a1: C.uintptr_t(sourceLen),
			a2: 0,
			a3: C.uintptr_t(uintptr(buf)),
		},
		blocking: true,
	})

	return C.GoString((*C.char)(buf))
}

// GetString reports current GL state.
//
// Valid name values:
//	EXTENSIONS
//	RENDERER
//	SHADING_LANGUAGE_VERSION
//	VENDOR
//	VERSION
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetString.xhtml
func GetString(pname Enum) string {
	ret := enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetString,
			a0: pname.c(),
		},
		blocking: true,
	})
	return C.GoString((*C.char)((unsafe.Pointer(uintptr(ret)))))
}

// GetTexParameterfv returns the float values of a texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetTexParameter.xhtml
func GetTexParameterfv(dst []float32, target, pname Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetTexParameterfv,
			a0: target.c(),
			a1: pname.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// GetTexParameteriv returns the int values of a texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetTexParameter.xhtml
func GetTexParameteriv(dst []int32, target, pname Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetTexParameteriv,
			a0: target.c(),
			a1: pname.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// GetUniformfv returns the float values of a uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetUniform.xhtml
func GetUniformfv(dst []float32, src Uniform, p Program) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetUniformfv,
			a0: p.c(),
			a1: src.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// GetUniformiv returns the float values of a uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetUniform.xhtml
func GetUniformiv(dst []int32, src Uniform, p Program) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetUniformiv,
			a0: p.c(),
			a1: src.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// GetUniformLocation returns the location of a uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetUniformLocation.xhtml
func GetUniformLocation(p Program, name string) Uniform {
	return Uniform{Value: int32(enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetUniformLocation,
			a0: p.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(C.CString(name)))),
		},
		blocking: true,
	}))}
}

// GetVertexAttribf reads the float value of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribf(src Attrib, pname Enum) float32 {
	var params [1]float32
	GetVertexAttribfv(params[:], src, pname)
	return params[0]
}

// GetVertexAttribfv reads float values of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribfv(dst []float32, src Attrib, pname Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetVertexAttribfv,
			a0: src.c(),
			a1: pname.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// GetVertexAttribi reads the int value of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribi(src Attrib, pname Enum) int32 {
	var params [1]int32
	GetVertexAttribiv(params[:], src, pname)
	return params[0]
}

// GetVertexAttribiv reads int values of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribiv(dst []int32, src Attrib, pname Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnGetVertexAttribiv,
			a0: src.c(),
			a1: pname.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// TODO(crawshaw): glGetVertexAttribPointerv

// Hint sets implementation-specific modes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glHint.xhtml
func Hint(target, mode Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnHint,
			a0: target.c(),
			a1: mode.c(),
		},
	})
}

// IsBuffer reports if b is a valid buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsBuffer.xhtml
func IsBuffer(b Buffer) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsBuffer,
			a0: b.c(),
		},
		blocking: true,
	})
}

// IsEnabled reports if cap is an enabled capability.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsEnabled.xhtml
func IsEnabled(cap Enum) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsEnabled,
			a0: cap.c(),
		},
		blocking: true,
	})
}

// IsFramebuffer reports if fb is a valid frame buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsFramebuffer.xhtml
func IsFramebuffer(fb Framebuffer) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsFramebuffer,
			a0: fb.c(),
		},
		blocking: true,
	})
}

// IsProgram reports if p is a valid program object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsProgram.xhtml
func IsProgram(p Program) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsProgram,
			a0: p.c(),
		},
		blocking: true,
	})
}

// IsRenderbuffer reports if rb is a valid render buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsRenderbuffer.xhtml
func IsRenderbuffer(rb Renderbuffer) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsRenderbuffer,
			a0: rb.c(),
		},
		blocking: true,
	})
}

// IsShader reports if s is valid shader.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsShader.xhtml
func IsShader(s Shader) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsShader,
			a0: s.c(),
		},
		blocking: true,
	})
}

// IsTexture reports if t is a valid texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsTexture.xhtml
func IsTexture(t Texture) bool {
	return 0 != enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnIsTexture,
			a0: t.c(),
		},
		blocking: true,
	})
}

// LineWidth specifies the width of lines.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glLineWidth.xhtml
func LineWidth(width float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnLineWidth,
			a0: C.uintptr_t(math.Float32bits(width)),
		},
	})
}

// LinkProgram links the specified program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glLinkProgram.xhtml
func LinkProgram(p Program) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnLinkProgram,
			a0: p.c(),
		},
	})
}

// PixelStorei sets pixel storage parameters.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glPixelStorei.xhtml
func PixelStorei(pname Enum, param int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnPixelStorei,
			a0: pname.c(),
			a1: C.uintptr_t(param),
		},
	})
}

// PolygonOffset sets the scaling factors for depth offsets.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glPolygonOffset.xhtml
func PolygonOffset(factor, units float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnPolygonOffset,
			a0: C.uintptr_t(math.Float32bits(factor)),
			a1: C.uintptr_t(math.Float32bits(units)),
		},
	})
}

// ReadPixels returns pixel data from a buffer.
//
// In GLES 3, the source buffer is controlled with ReadBuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glReadPixels.xhtml
func ReadPixels(dst []byte, x, y, width, height int, format, ty Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnReadPixels,
			// TODO(crawshaw): support PIXEL_PACK_BUFFER in GLES3, uses offset.
			a0: C.uintptr_t(x),
			a1: C.uintptr_t(y),
			a2: C.uintptr_t(width),
			a3: C.uintptr_t(height),
			a4: format.c(),
			a5: ty.c(),
			a6: C.uintptr_t(uintptr(unsafe.Pointer(&dst[0]))),
		},
		blocking: true,
	})
}

// ReleaseShaderCompiler frees resources allocated by the shader compiler.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glReleaseShaderCompiler.xhtml
func ReleaseShaderCompiler() {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnReleaseShaderCompiler,
		},
	})
}

// RenderbufferStorage establishes the data storage, format, and
// dimensions of a renderbuffer object's image.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glRenderbufferStorage.xhtml
func RenderbufferStorage(target, internalFormat Enum, width, height int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnRenderbufferStorage,
			a0: target.c(),
			a1: internalFormat.c(),
			a2: C.uintptr_t(width),
			a3: C.uintptr_t(height),
		},
	})
}

// SampleCoverage sets multisample coverage parameters.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glSampleCoverage.xhtml
func SampleCoverage(value float32, invert bool) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnSampleCoverage,
			a0: C.uintptr_t(math.Float32bits(value)),
			a1: glBoolean(invert),
		},
	})
}

// Scissor defines the scissor box rectangle, in window coordinates.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glScissor.xhtml
func Scissor(x, y, width, height int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnScissor,
			a0: C.uintptr_t(x),
			a1: C.uintptr_t(y),
			a2: C.uintptr_t(width),
			a3: C.uintptr_t(height),
		},
	})
}

// TODO(crawshaw): ShaderBinary

// ShaderSource sets the source code of s to the given source code.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glShaderSource.xhtml
func ShaderSource(s Shader, src string) {
	// We are passing a char**. Make sure both the string and its
	// containing 1-element array are off the stack. Both are freed
	// in work.c.
	cstr := C.CString(src)
	cstrp := (**C.char)(C.malloc(C.size_t(unsafe.Sizeof(cstr))))
	*cstrp = cstr

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnShaderSource,
			a0: s.c(),
			a1: 1,
			a2: C.uintptr_t(uintptr(unsafe.Pointer(cstrp))),
		},
	})
}

// StencilFunc sets the front and back stencil test reference value.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilFunc.xhtml
func StencilFunc(fn Enum, ref int, mask uint32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnStencilFunc,
			a0: fn.c(),
			a1: C.uintptr_t(ref),
			a2: C.uintptr_t(mask),
		},
	})
}

// StencilFunc sets the front or back stencil test reference value.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilFuncSeparate.xhtml
func StencilFuncSeparate(face, fn Enum, ref int, mask uint32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnStencilFuncSeparate,
			a0: face.c(),
			a1: fn.c(),
			a2: C.uintptr_t(ref),
			a3: C.uintptr_t(mask),
		},
	})
}

// StencilMask controls the writing of bits in the stencil planes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilMask.xhtml
func StencilMask(mask uint32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnStencilMask,
			a0: C.uintptr_t(mask),
		},
	})
}

// StencilMaskSeparate controls the writing of bits in the stencil planes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilMaskSeparate.xhtml
func StencilMaskSeparate(face Enum, mask uint32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnStencilMaskSeparate,
			a0: face.c(),
			a1: C.uintptr_t(mask),
		},
	})
}

// StencilOp sets front and back stencil test actions.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilOp.xhtml
func StencilOp(fail, zfail, zpass Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnStencilOp,
			a0: fail.c(),
			a1: zfail.c(),
			a2: zpass.c(),
		},
	})
}

// StencilOpSeparate sets front or back stencil tests.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilOpSeparate.xhtml
func StencilOpSeparate(face, sfail, dpfail, dppass Enum) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnStencilOpSeparate,
			a0: face.c(),
			a1: sfail.c(),
			a2: dpfail.c(),
			a3: dppass.c(),
		},
	})
}

// TexImage2D writes a 2D texture image.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexImage2D.xhtml
func TexImage2D(target Enum, level int, width, height int, format Enum, ty Enum, data []byte) {
	// It is common to pass TexImage2D a nil data, indicating that a
	// bound GL buffer is being used as the source. In that case, it
	// is not necessary to block.
	blocking, a7 := false, C.uintptr_t(0)
	if len(data) > 0 {
		blocking, a7 = true, C.uintptr_t(uintptr(unsafe.Pointer(&data[0])))
	}

	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnTexImage2D,
			// TODO(crawshaw): GLES3 offset for PIXEL_UNPACK_BUFFER and PIXEL_PACK_BUFFER.
			a0: target.c(),
			a1: C.uintptr_t(level),
			a2: C.uintptr_t(format),
			a3: C.uintptr_t(width),
			a4: C.uintptr_t(height),
			a5: format.c(),
			a6: ty.c(),
			a7: a7,
		},
		blocking: blocking,
	})
}

// TexSubImage2D writes a subregion of a 2D texture image.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexSubImage2D.xhtml
func TexSubImage2D(target Enum, level int, x, y, width, height int, format, ty Enum, data []byte) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnTexSubImage2D,
			// TODO(crawshaw): GLES3 offset for PIXEL_UNPACK_BUFFER and PIXEL_PACK_BUFFER.
			a0: target.c(),
			a1: C.uintptr_t(level),
			a2: C.uintptr_t(x),
			a3: C.uintptr_t(y),
			a4: C.uintptr_t(width),
			a5: C.uintptr_t(height),
			a6: format.c(),
			a7: ty.c(),
			a8: C.uintptr_t(uintptr(unsafe.Pointer(&data[0]))),
		},
		blocking: true,
	})
}

// TexParameterf sets a float texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameterf(target, pname Enum, param float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnTexParameterf,
			a0: target.c(),
			a1: pname.c(),
			a2: C.uintptr_t(math.Float32bits(param)),
		},
	})
}

// TexParameterfv sets a float texture parameter array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameterfv(target, pname Enum, params []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnTexParameterfv,
			a0: target.c(),
			a1: pname.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&params[0]))),
		},
		blocking: true,
	})
}

// TexParameteri sets an integer texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameteri(target, pname Enum, param int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnTexParameteri,
			a0: target.c(),
			a1: pname.c(),
			a2: C.uintptr_t(param),
		},
	})
}

// TexParameteriv sets an integer texture parameter array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameteriv(target, pname Enum, params []int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnTexParameteriv,
			a0: target.c(),
			a1: pname.c(),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&params[0]))),
		},
		blocking: true,
	})
}

// Uniform1f writes a float uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1f(dst Uniform, v float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform1f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(v)),
		},
	})
}

// Uniform1fv writes a [len(src)]float uniform array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform1fv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src)),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform1i writes an int uniform variable.
//
// Uniform1i and Uniform1iv are the only two functions that may be used
// to load uniform variables defined as sampler types. Loading samplers
// with any other function will result in a INVALID_OPERATION error.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1i(dst Uniform, v int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform1i,
			a0: dst.c(),
			a1: C.uintptr_t(v),
		},
	})
}

// Uniform1iv writes a int uniform array of len(src) elements.
//
// Uniform1i and Uniform1iv are the only two functions that may be used
// to load uniform variables defined as sampler types. Loading samplers
// with any other function will result in a INVALID_OPERATION error.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1iv(dst Uniform, src []int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform1iv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src)),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform2f writes a vec2 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2f(dst Uniform, v0, v1 float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform2f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(v0)),
			a2: C.uintptr_t(math.Float32bits(v1)),
		},
	})
}

// Uniform2fv writes a vec2 uniform array of len(src)/2 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform2fv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 2),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform2i writes an ivec2 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2i(dst Uniform, v0, v1 int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform2i,
			a0: dst.c(),
			a1: C.uintptr_t(v0),
			a2: C.uintptr_t(v1),
		},
	})
}

// Uniform2iv writes an ivec2 uniform array of len(src)/2 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2iv(dst Uniform, src []int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform2iv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 2),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform3f writes a vec3 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3f(dst Uniform, v0, v1, v2 float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform3f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(v0)),
			a2: C.uintptr_t(math.Float32bits(v1)),
			a3: C.uintptr_t(math.Float32bits(v2)),
		},
	})
}

// Uniform3fv writes a vec3 uniform array of len(src)/3 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform3fv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 3),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform3i writes an ivec3 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3i(dst Uniform, v0, v1, v2 int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform3i,
			a0: dst.c(),
			a1: C.uintptr_t(v0),
			a2: C.uintptr_t(v1),
			a3: C.uintptr_t(v2),
		},
	})
}

// Uniform3iv writes an ivec3 uniform array of len(src)/3 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3iv(dst Uniform, src []int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform3iv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 3),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform4f writes a vec4 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4f(dst Uniform, v0, v1, v2, v3 float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform4f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(v0)),
			a2: C.uintptr_t(math.Float32bits(v1)),
			a3: C.uintptr_t(math.Float32bits(v2)),
			a4: C.uintptr_t(math.Float32bits(v3)),
		},
	})
}

// Uniform4fv writes a vec4 uniform array of len(src)/4 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform4fv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 4),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// Uniform4i writes an ivec4 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4i(dst Uniform, v0, v1, v2, v3 int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform4i,
			a0: dst.c(),
			a1: C.uintptr_t(v0),
			a2: C.uintptr_t(v1),
			a3: C.uintptr_t(v2),
			a4: C.uintptr_t(v3),
		},
	})
}

// Uniform4i writes an ivec4 uniform array of len(src)/4 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4iv(dst Uniform, src []int32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniform4iv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 4),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// UniformMatrix2fv writes 2x2 matrices. Each matrix uses four
// float32 values, so the number of matrices written is len(src)/4.
//
// Each matrix must be supplied in column major order.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func UniformMatrix2fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniformMatrix2fv,
			// OpenGL ES 2 does not support transpose.
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 4),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// UniformMatrix3fv writes 3x3 matrices. Each matrix uses nine
// float32 values, so the number of matrices written is len(src)/9.
//
// Each matrix must be supplied in column major order.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func UniformMatrix3fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniformMatrix3fv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 9),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// UniformMatrix4fv writes 4x4 matrices. Each matrix uses 16
// float32 values, so the number of matrices written is len(src)/16.
//
// Each matrix must be supplied in column major order.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func UniformMatrix4fv(dst Uniform, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUniformMatrix4fv,
			a0: dst.c(),
			a1: C.uintptr_t(len(src) / 16),
			a2: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// UseProgram sets the active program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUseProgram.xhtml
func UseProgram(p Program) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnUseProgram,
			a0: p.c(),
		},
	})
}

// ValidateProgram checks to see whether the executables contained in
// program can execute given the current OpenGL state.
//
// Typically only used for debugging.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glValidateProgram.xhtml
func ValidateProgram(p Program) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnValidateProgram,
			a0: p.c(),
		},
	})
}

// VertexAttrib1f writes a float vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib1f(dst Attrib, x float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib1f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(x)),
		},
	})
}

// VertexAttrib1fv writes a float vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib1fv(dst Attrib, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib1fv,
			a0: dst.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// VertexAttrib2f writes a vec2 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib2f(dst Attrib, x, y float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib2f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(x)),
			a2: C.uintptr_t(math.Float32bits(y)),
		},
	})
}

// VertexAttrib2fv writes a vec2 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib2fv(dst Attrib, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib2fv,
			a0: dst.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// VertexAttrib3f writes a vec3 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib3f(dst Attrib, x, y, z float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib3f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(x)),
			a2: C.uintptr_t(math.Float32bits(y)),
			a3: C.uintptr_t(math.Float32bits(z)),
		},
	})
}

// VertexAttrib3fv writes a vec3 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib3fv(dst Attrib, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib3fv,
			a0: dst.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// VertexAttrib4f writes a vec4 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib4f(dst Attrib, x, y, z, w float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib4f,
			a0: dst.c(),
			a1: C.uintptr_t(math.Float32bits(x)),
			a2: C.uintptr_t(math.Float32bits(y)),
			a3: C.uintptr_t(math.Float32bits(z)),
			a4: C.uintptr_t(math.Float32bits(w)),
		},
	})
}

// VertexAttrib4fv writes a vec4 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib4fv(dst Attrib, src []float32) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttrib4fv,
			a0: dst.c(),
			a1: C.uintptr_t(uintptr(unsafe.Pointer(&src[0]))),
		},
		blocking: true,
	})
}

// VertexAttribPointer uses a bound buffer to define vertex attribute data.
//
// Direct use of VertexAttribPointer to load data into OpenGL is not
// supported via the Go bindings. Instead, use BindBuffer with an
// ARRAY_BUFFER and then fill it using BufferData.
//
// The size argument specifies the number of components per attribute,
// between 1-4. The stride argument specifies the byte offset between
// consecutive vertex attributes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttribPointer.xhtml
func VertexAttribPointer(dst Attrib, size int, ty Enum, normalized bool, stride, offset int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnVertexAttribPointer,
			a0: dst.c(),
			a1: C.uintptr_t(size),
			a2: ty.c(),
			a3: glBoolean(normalized),
			a4: C.uintptr_t(stride),
			a5: C.uintptr_t(offset),
		},
	})
}

// Viewport sets the viewport, an affine transformation that
// normalizes device coordinates to window coordinates.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glViewport.xhtml
func Viewport(x, y, width, height int) {
	enqueue(call{
		args: C.struct_fnargs{
			fn: C.glfnViewport,
			a0: C.uintptr_t(x),
			a1: C.uintptr_t(y),
			a2: C.uintptr_t(width),
			a3: C.uintptr_t(height),
		},
	})
}
