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

/*
#include <stdlib.h>

#ifdef os_linux
#include <GLES2/gl2.h>
#endif
#ifdef os_darwin_arm
#include <OpenGLES/ES2/glext.h>
#endif
#ifdef os_darwin_amd64
#include <OpenGL/gl3.h>
#endif
*/
import "C"

import "unsafe"

// ActiveTexture sets the active texture unit.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glActiveTexture.xhtml
func ActiveTexture(texture Enum) {
	C.glActiveTexture(texture.c())
}

// AttachShader attaches a shader to a program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glAttachShader.xhtml
func AttachShader(p Program, s Shader) {
	C.glAttachShader(p.c(), s.c())
}

// BindAttribLocation binds a vertex attribute index with a named
// variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindAttribLocation.xhtml
func BindAttribLocation(p Program, a Attrib, name string) {
	str := unsafe.Pointer(C.CString(name))
	defer C.free(str)
	C.glBindAttribLocation(p.c(), a.c(), (*C.GLchar)(str))
}

// BindBuffer binds a buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindBuffer.xhtml
func BindBuffer(target Enum, b Buffer) {
	C.glBindBuffer(target.c(), b.c())
}

// BindFramebuffer binds a framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindFramebuffer.xhtml
func BindFramebuffer(target Enum, fb Framebuffer) {
	C.glBindFramebuffer(target.c(), fb.c())
}

// BindRenderbuffer binds a render buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindRenderbuffer.xhtml
func BindRenderbuffer(target Enum, rb Renderbuffer) {
	C.glBindRenderbuffer(target.c(), rb.c())
}

// BindTexture binds a texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBindTexture.xhtml
func BindTexture(target Enum, t Texture) {
	C.glBindTexture(target.c(), t.c())
}

// BlendColor sets the blend color.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendColor.xhtml
func BlendColor(red, green, blue, alpha float32) {
	blendColor(red, green, blue, alpha)
}

// BlendEquation sets both RGB and alpha blend equations.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendEquation.xhtml
func BlendEquation(mode Enum) {
	C.glBlendEquation(mode.c())
}

// BlendEquationSeparate sets RGB and alpha blend equations separately.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendEquationSeparate.xhtml
func BlendEquationSeparate(modeRGB, modeAlpha Enum) {
	C.glBlendEquationSeparate(modeRGB.c(), modeAlpha.c())
}

// BlendFunc sets the pixel blending factors.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendFunc.xhtml
func BlendFunc(sfactor, dfactor Enum) {
	C.glBlendFunc(sfactor.c(), dfactor.c())
}

// BlendFunc sets the pixel RGB and alpha blending factors separately.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBlendFuncSeparate.xhtml
func BlendFuncSeparate(sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha Enum) {
	C.glBlendFuncSeparate(sfactorRGB.c(), dfactorRGB.c(), sfactorAlpha.c(), dfactorAlpha.c())
}

// BufferData creates a new data store for the bound buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBufferData.xhtml
func BufferData(target Enum, src []byte, usage Enum) {
	C.glBufferData(target.c(), C.GLsizeiptr(len(src)), unsafe.Pointer(&src[0]), usage.c())
}

// BufferInit creates a new unitialized data store for the bound buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBufferData.xhtml
func BufferInit(target Enum, size int, usage Enum) {
	C.glBufferData(target.c(), C.GLsizeiptr(size), nil, usage.c())
}

// BufferSubData sets some of data in the bound buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glBufferSubData.xhtml
func BufferSubData(target Enum, offset int, data []byte) {
	C.glBufferSubData(target.c(), C.GLintptr(offset), C.GLsizeiptr(len(data)), unsafe.Pointer(&data[0]))
}

// CheckFramebufferStatus reports the completeness status of the
// active framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCheckFramebufferStatus.xhtml
func CheckFramebufferStatus(target Enum) Enum {
	return Enum(C.glCheckFramebufferStatus(target.c()))
}

// Clear clears the window.
//
// The behavior of Clear is influenced by the pixel ownership test,
// the scissor test, dithering, and the buffer writemasks.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClear.xhtml
func Clear(mask Enum) {
	C.glClear(C.GLbitfield(mask))
}

// ClearColor specifies the RGBA values used to clear color buffers.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClearColor.xhtml
func ClearColor(red, green, blue, alpha float32) {
	clearColor(red, green, blue, alpha)
}

// ClearDepthf sets the depth value used to clear the depth buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClearDepthf.xhtml
func ClearDepthf(d float32) {
	clearDepthf(d)
}

// ClearStencil sets the index used to clear the stencil buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glClearStencil.xhtml
func ClearStencil(s int) {
	C.glClearStencil(C.GLint(s))
}

// ColorMask specifies whether color components in the framebuffer
// can be written.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glColorMask.xhtml
func ColorMask(red, green, blue, alpha bool) {
	C.glColorMask(glBoolean(red), glBoolean(green), glBoolean(blue), glBoolean(alpha))
}

// CompileShader compiles the source code of s.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCompileShader.xhtml
func CompileShader(s Shader) {
	C.glCompileShader(s.c())
}

// CompressedTexImage2D writes a compressed 2D texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCompressedTexImage2D.xhtml
func CompressedTexImage2D(target Enum, level int, internalformat Enum, width, height, border int, data []byte) {
	C.glCompressedTexImage2D(target.c(), C.GLint(level), internalformat.c(), C.GLsizei(width), C.GLsizei(height), C.GLint(border), C.GLsizei(len(data)), unsafe.Pointer(&data[0]))
}

// CompressedTexSubImage2D writes a subregion of a compressed 2D texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCompressedTexSubImage2D.xhtml
func CompressedTexSubImage2D(target Enum, level, xoffset, yoffset, width, height int, format Enum, data []byte) {
	C.glCompressedTexSubImage2D(target.c(), C.GLint(level), C.GLint(xoffset), C.GLint(yoffset), C.GLsizei(width), C.GLsizei(height), format.c(), C.GLsizei(len(data)), unsafe.Pointer(&data[0]))
}

// CopyTexImage2D writes a 2D texture from the current framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCopyTexImage2D.xhtml
func CopyTexImage2D(target Enum, level int, internalformat Enum, x, y, width, height, border int) {
	C.glCopyTexImage2D(target.c(), C.GLint(level), internalformat.c(), C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height), C.GLint(border))
}

// CopyTexSubImage2D writes a 2D texture subregion from the
// current framebuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCopyTexSubImage2D.xhtml
func CopyTexSubImage2D(target Enum, level, xoffset, yoffset, x, y, width, height int) {
	C.glCopyTexSubImage2D(target.c(), C.GLint(level), C.GLint(xoffset), C.GLint(yoffset), C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height))
}

// CreateBuffer creates a buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenBuffers.xhtml
func CreateBuffer() Buffer {
	var b Buffer
	C.glGenBuffers(1, (*C.GLuint)(&b.Value))
	return b
}

// CreateFramebuffer creates a framebuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenFramebuffers.xhtml
func CreateFramebuffer() Framebuffer {
	var b Framebuffer
	C.glGenFramebuffers(1, (*C.GLuint)(&b.Value))
	return b
}

// CreateProgram creates a new empty program object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCreateProgram.xhtml
func CreateProgram() Program {
	return Program{Value: uint32(C.glCreateProgram())}
}

// CreateRenderbuffer create a renderbuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenRenderbuffers.xhtml
func CreateRenderbuffer() Renderbuffer {
	var b Renderbuffer
	C.glGenRenderbuffers(1, (*C.GLuint)(&b.Value))
	return b
}

// CreateShader creates a new empty shader object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCreateShader.xhtml
func CreateShader(ty Enum) Shader {
	return Shader{Value: uint32(C.glCreateShader(ty.c()))}
}

// CreateTexture creates a texture object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenTextures.xhtml
func CreateTexture() Texture {
	var t Texture
	C.glGenTextures(1, (*C.GLuint)(&t.Value))
	return t
}

// CullFace specifies which polygons are candidates for culling.
//
// Valid modes: FRONT, BACK, FRONT_AND_BACK.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glCullFace.xhtml
func CullFace(mode Enum) {
	C.glCullFace(mode.c())
}

// DeleteBuffer deletes the given buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteBuffers.xhtml
func DeleteBuffer(v Buffer) {
	C.glDeleteBuffers(1, (*C.GLuint)(&v.Value))
}

// DeleteFramebuffer deletes the given framebuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteFramebuffers.xhtml
func DeleteFramebuffer(v Framebuffer) {
	C.glDeleteFramebuffers(1, (*C.GLuint)(&v.Value))
}

// DeleteProgram deletes the given program object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteProgram.xhtml
func DeleteProgram(p Program) {
	C.glDeleteProgram(p.c())
}

// DeleteRenderbuffer deletes the given render buffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteRenderbuffers.xhtml
func DeleteRenderbuffer(v Renderbuffer) {
	C.glDeleteRenderbuffers(1, (*C.GLuint)(&v.Value))
}

// DeleteShader deletes shader s.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteShader.xhtml
func DeleteShader(s Shader) {
	C.glDeleteShader(s.c())
}

// DeleteTexture deletes the given texture object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDeleteTextures.xhtml
func DeleteTexture(v Texture) {
	C.glDeleteTextures(1, (*C.GLuint)(&v.Value))
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
	C.glDepthFunc(fn.c())
}

// DepthMask sets the depth buffer enabled for writing.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDepthMask.xhtml
func DepthMask(flag bool) {
	C.glDepthMask(glBoolean(flag))
}

// DepthRangef sets the mapping from normalized device coordinates to
// window coordinates.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDepthRangef.xhtml
func DepthRangef(n, f float32) {
	depthRangef(n, f)
}

// DetachShader detaches the shader s from the program p.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDetachShader.xhtml
func DetachShader(p Program, s Shader) {
	C.glDetachShader(p.c(), s.c())
}

// Disable disables various GL capabilities.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDisable.xhtml
func Disable(cap Enum) {
	C.glDisable(cap.c())
}

// http://www.khronos.org/opengles/sdk/docs/man3/html/glDisableVertexAttribArray.xhtml
func DisableVertexAttribArray(a Attrib) {
	C.glDisableVertexAttribArray(a.c())
}

// DrawArrays renders geometric primitives from the bound data.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDrawArrays.xhtml
func DrawArrays(mode Enum, first, count int) {
	C.glDrawArrays(mode.c(), C.GLint(first), C.GLsizei(count))
}

// DrawElements renders primitives from a bound buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glDrawElements.xhtml
func DrawElements(mode Enum, count int, ty Enum, offset int) {
	C.glDrawElements(mode.c(), C.GLsizei(count), ty.c(), unsafe.Pointer(uintptr(offset)))
}

// TODO(crawshaw): consider DrawElements8 / DrawElements16 / DrawElements32

// Enable enables various GL capabilities.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glEnable.xhtml
func Enable(cap Enum) {
	C.glEnable(cap.c())
}

// EnableVertexAttribArray enables a vertex attribute array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glEnableVertexAttribArray.xhtml
func EnableVertexAttribArray(a Attrib) {
	C.glEnableVertexAttribArray(a.c())
}

// Finish blocks until the effects of all previously called GL
// commands are complete.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFinish.xhtml
func Finish() {
	C.glFinish()
}

// Flush empties all buffers. It does not block.
//
// An OpenGL implementation may buffer network communication,
// the command stream, or data inside the graphics accelerator.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFlush.xhtml
func Flush() {
	C.glFlush()
}

// FramebufferRenderbuffer attaches rb to the current frame buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFramebufferRenderbuffer.xhtml
func FramebufferRenderbuffer(target, attachment, rbTarget Enum, rb Renderbuffer) {
	C.glFramebufferRenderbuffer(target.c(), attachment.c(), rbTarget.c(), rb.c())
}

// FramebufferTexture2D attaches the t to the current frame buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFramebufferTexture2D.xhtml
func FramebufferTexture2D(target, attachment, texTarget Enum, t Texture, level int) {
	C.glFramebufferTexture2D(target.c(), attachment.c(), texTarget.c(), t.c(), C.GLint(level))
}

// FrontFace defines which polygons are front-facing.
//
// Valid modes: CW, CCW.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glFrontFace.xhtml
func FrontFace(mode Enum) {
	C.glFrontFace(mode.c())
}

// GenerateMipmap generates mipmaps for the current texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGenerateMipmap.xhtml
func GenerateMipmap(target Enum) {
	C.glGenerateMipmap(target.c())
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
	C.glGetActiveAttrib(p.c(), C.GLuint(index), C.GLsizei(bufSize), nil, &cSize, &cType, (*C.GLchar)(buf))
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

	C.glGetActiveUniform(p.c(), C.GLuint(index), C.GLsizei(bufSize), nil, &cSize, &cType, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf)), int(cSize), Enum(cType)
}

// GetAttachedShaders returns the shader objects attached to program p.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetAttachedShaders.xhtml
func GetAttachedShaders(p Program) []Shader {
	shadersLen := GetProgrami(p, ATTACHED_SHADERS)
	var n C.GLsizei
	buf := make([]C.GLuint, shadersLen)
	C.glGetAttachedShaders(p.c(), C.GLsizei(shadersLen), &n, &buf[0])
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
	str := unsafe.Pointer(C.CString(name))
	defer C.free(str)
	return Attrib{Value: uint(C.glGetAttribLocation(p.c(), (*C.GLchar)(str)))}
}

// GetBooleanv returns the boolean values of parameter pname.
//
// Many boolean parameters can be queried more easily using IsEnabled.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetBooleanv(dst []bool, pname Enum) {
	buf := make([]C.GLboolean, len(dst))
	C.glGetBooleanv(pname.c(), &buf[0])
	for i, v := range buf {
		dst[i] = v != 0
	}
}

// GetFloatv returns the float values of parameter pname.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetFloatv(dst []float32, pname Enum) {
	C.glGetFloatv(pname.c(), (*C.GLfloat)(&dst[0]))
}

// GetIntegerv returns the int values of parameter pname.
//
// Single values may be queried more easily using GetInteger.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetIntegerv(pname Enum, data []int32) {
	buf := make([]C.GLint, len(data))
	C.glGetIntegerv(pname.c(), &buf[0])
	for i, v := range buf {
		data[i] = int32(v)
	}
}

// GetInteger returns the int value of parameter pname.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGet.xhtml
func GetInteger(pname Enum) int {
	var v C.GLint
	C.glGetIntegerv(pname.c(), &v)
	return int(v)
}

// GetBufferParameteri returns a parameter for the active buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetBufferParameteriv.xhtml
func GetBufferParameteri(target, pname Enum) int {
	var params C.GLint
	C.glGetBufferParameteriv(target.c(), pname.c(), &params)
	return int(params)
}

// GetError returns the next error.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetError.xhtml
func GetError() Enum {
	return Enum(C.glGetError())
}

// GetFramebufferAttachmentParameteri returns attachment parameters
// for the active framebuffer object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetFramebufferAttachmentParameteriv.xhtml
func GetFramebufferAttachmentParameteri(target, attachment, pname Enum) int {
	var params C.GLint
	C.glGetFramebufferAttachmentParameteriv(target.c(), attachment.c(), pname.c(), &params)
	return int(params)
}

// GetProgrami returns a parameter value for a program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetProgramiv.xhtml
func GetProgrami(p Program, pname Enum) int {
	var params C.GLint
	C.glGetProgramiv(p.c(), pname.c(), &params)
	return int(params)
}

// GetProgramInfoLog returns the information log for a program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetProgramInfoLog.xhtml
func GetProgramInfoLog(p Program) string {
	infoLen := GetProgrami(p, INFO_LOG_LENGTH)
	buf := C.malloc(C.size_t(infoLen))
	C.free(buf)
	C.glGetProgramInfoLog(p.c(), C.GLsizei(infoLen), nil, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf))
}

// GetRenderbufferParameteri returns a parameter value for a render buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetRenderbufferParameteriv.xhtml
func GetRenderbufferParameteri(target, pname Enum) int {
	var params C.GLint
	C.glGetRenderbufferParameteriv(target.c(), pname.c(), &params)
	return int(params)
}

// GetRenderbufferParameteri returns a parameter value for a shader.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderiv.xhtml
func GetShaderi(s Shader, pname Enum) int {
	var params C.GLint
	C.glGetShaderiv(s.c(), pname.c(), &params)
	return int(params)
}

// GetShaderInfoLog returns the information log for a shader.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderInfoLog.xhtml
func GetShaderInfoLog(s Shader) string {
	infoLen := GetShaderi(s, INFO_LOG_LENGTH)
	buf := C.malloc(C.size_t(infoLen))
	defer C.free(buf)
	C.glGetShaderInfoLog(s.c(), C.GLsizei(infoLen), nil, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf))
}

// GetShaderPrecisionFormat returns range and precision limits for
// shader types.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetShaderPrecisionFormat.xhtml
func GetShaderPrecisionFormat(shadertype, precisiontype Enum) (rangeLow, rangeHigh, precision int) {
	const glintSize = 4
	var cRange [2]C.GLint
	var cPrecision C.GLint

	C.glGetShaderPrecisionFormat(shadertype.c(), precisiontype.c(), &cRange[0], &cPrecision)
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
	C.glGetShaderSource(s.c(), C.GLsizei(sourceLen), nil, (*C.GLchar)(buf))
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
	// Bounce through unsafe.Pointer, because on some platforms
	// GetString returns an *unsigned char which doesn't convert.
	return C.GoString((*C.char)((unsafe.Pointer)(C.glGetString(pname.c()))))
}

// GetTexParameterfv returns the float values of a texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetTexParameter.xhtml
func GetTexParameterfv(dst []float32, target, pname Enum) {
	C.glGetTexParameterfv(target.c(), pname.c(), (*C.GLfloat)(&dst[0]))
}

// GetTexParameteriv returns the int values of a texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetTexParameter.xhtml
func GetTexParameteriv(dst []int32, target, pname Enum) {
	C.glGetTexParameteriv(target.c(), pname.c(), (*C.GLint)(&dst[0]))
}

// GetUniformfv returns the float values of a uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetUniform.xhtml
func GetUniformfv(dst []float32, src Uniform, p Program) {
	C.glGetUniformfv(p.c(), src.c(), (*C.GLfloat)(&dst[0]))
}

// GetUniformiv returns the float values of a uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetUniform.xhtml
func GetUniformiv(dst []int32, src Uniform, p Program) {
	C.glGetUniformiv(p.c(), src.c(), (*C.GLint)(&dst[0]))
}

// GetUniformLocation returns the location of a uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetUniformLocation.xhtml
func GetUniformLocation(p Program, name string) Uniform {
	str := unsafe.Pointer(C.CString(name))
	defer C.free(str)
	return Uniform{Value: int32(C.glGetUniformLocation(p.c(), (*C.GLchar)(str)))}
}

// GetVertexAttribf reads the float value of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribf(src Attrib, pname Enum) float32 {
	var params C.GLfloat
	C.glGetVertexAttribfv(src.c(), pname.c(), &params)
	return float32(params)
}

// GetVertexAttribfv reads float values of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribfv(dst []float32, src Attrib, pname Enum) {
	C.glGetVertexAttribfv(src.c(), pname.c(), (*C.GLfloat)(&dst[0]))
}

// GetVertexAttribi reads the int value of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribi(src Attrib, pname Enum) int32 {
	var params C.GLint
	C.glGetVertexAttribiv(src.c(), pname.c(), &params)
	return int32(params)
}

// GetVertexAttribiv reads int values of a vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glGetVertexAttrib.xhtml
func GetVertexAttribiv(dst []int32, src Attrib, pname Enum) {
	C.glGetVertexAttribiv(src.c(), pname.c(), (*C.GLint)(&dst[0]))
}

// TODO(crawshaw): glGetVertexAttribPointerv

// Hint sets implementation-specific modes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glHint.xhtml
func Hint(target, mode Enum) {
	C.glHint(target.c(), mode.c())
}

// IsBuffer reports if b is a valid buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsBuffer.xhtml
func IsBuffer(b Buffer) bool {
	return C.glIsBuffer(b.c()) != 0
}

// IsEnabled reports if cap is an enabled capability.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsEnabled.xhtml
func IsEnabled(cap Enum) bool {
	return C.glIsEnabled(cap.c()) != 0
}

// IsFramebuffer reports if fb is a valid frame buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsFramebuffer.xhtml
func IsFramebuffer(fb Framebuffer) bool {
	return C.glIsFramebuffer(fb.c()) != 0
}

// IsProgram reports if p is a valid program object.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsProgram.xhtml
func IsProgram(p Program) bool {
	return C.glIsProgram(p.c()) != 0
}

// IsRenderbuffer reports if rb is a valid render buffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsRenderbuffer.xhtml
func IsRenderbuffer(rb Renderbuffer) bool {
	return C.glIsRenderbuffer(rb.c()) != 0
}

// IsShader reports if s is valid shader.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsShader.xhtml
func IsShader(s Shader) bool {
	return C.glIsShader(s.c()) != 0
}

// IsTexture reports if t is a valid texture.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glIsTexture.xhtml
func IsTexture(t Texture) bool {
	return C.glIsTexture(t.c()) != 0
}

// LineWidth specifies the width of lines.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glLineWidth.xhtml
func LineWidth(width float32) {
	C.glLineWidth(C.GLfloat(width))
}

// LinkProgram links the specified program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glLinkProgram.xhtml
func LinkProgram(p Program) {
	C.glLinkProgram(p.c())
}

// PixelStorei sets pixel storage parameters.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glPixelStorei.xhtml
func PixelStorei(pname Enum, param int32) {
	C.glPixelStorei(pname.c(), C.GLint(param))
}

// PolygonOffset sets the scaling factors for depth offsets.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glPolygonOffset.xhtml
func PolygonOffset(factor, units float32) {
	C.glPolygonOffset(C.GLfloat(factor), C.GLfloat(units))
}

// ReadPixels returns pixel data from a buffer.
//
// In GLES 3, the source buffer is controlled with ReadBuffer.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glReadPixels.xhtml
func ReadPixels(dst []byte, x, y, width, height int, format, ty Enum) {
	// TODO(crawshaw): support PIXEL_PACK_BUFFER in GLES3, uses offset.
	C.glReadPixels(C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height), format.c(), ty.c(), unsafe.Pointer(&dst[0]))
}

// ReleaseShaderCompiler frees resources allocated by the shader compiler.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glReleaseShaderCompiler.xhtml
func ReleaseShaderCompiler() {
	C.glReleaseShaderCompiler()
}

// RenderbufferStorage establishes the data storage, format, and
// dimensions of a renderbuffer object's image.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glRenderbufferStorage.xhtml
func RenderbufferStorage(target, internalFormat Enum, width, height int) {
	C.glRenderbufferStorage(target.c(), internalFormat.c(), C.GLsizei(width), C.GLsizei(height))
}

// SampleCoverage sets multisample coverage parameters.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glSampleCoverage.xhtml
func SampleCoverage(value float32, invert bool) {
	sampleCoverage(value, invert)
}

// Scissor defines the scissor box rectangle, in window coordinates.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glScissor.xhtml
func Scissor(x, y, width, height int32) {
	C.glScissor(C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height))
}

// TODO(crawshaw): ShaderBinary

// ShaderSource sets the source code of s to the given source code.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glShaderSource.xhtml
func ShaderSource(s Shader, src string) {
	str := (*C.GLchar)(C.CString(src))
	defer C.free(unsafe.Pointer(str))
	C.glShaderSource(s.c(), 1, &str, nil)
}

//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilFunc.xhtml
func StencilFunc(fn Enum, ref int, mask uint32) {
	C.glStencilFunc(fn.c(), C.GLint(ref), C.GLuint(mask))
}

//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilFuncSeparate.xhtml
func StencilFuncSeparate(face, fn Enum, ref int, mask uint32) {
	C.glStencilFuncSeparate(face.c(), fn.c(), C.GLint(ref), C.GLuint(mask))
}

// StencilMask controls the writing of bits in the stencil planes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilMask.xhtml
func StencilMask(mask uint32) {
	C.glStencilMask(C.GLuint(mask))
}

// StencilMaskSeparate controls the writing of bits in the stencil planes.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilMaskSeparate.xhtml
func StencilMaskSeparate(face Enum, mask uint32) {
	C.glStencilMaskSeparate(face.c(), C.GLuint(mask))
}

// StencilOp sets front and back stencil test actions.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilOp.xhtml
func StencilOp(fail, zfail, zpass Enum) {
	C.glStencilOp(fail.c(), zfail.c(), zpass.c())
}

// StencilOpSeparate sets front or back stencil tests.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glStencilOpSeparate.xhtml
func StencilOpSeparate(face, sfail, dpfail, dppass Enum) {
	C.glStencilOpSeparate(face.c(), sfail.c(), dpfail.c(), dppass.c())
}

// TexImage2D writes a 2D texture image.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexImage2D.xhtml
func TexImage2D(target Enum, level int, width, height int, format Enum, ty Enum, data []byte) {
	// TODO(crawshaw): GLES3 offset for PIXEL_UNPACK_BUFFER and PIXEL_PACK_BUFFER.
	p := unsafe.Pointer(nil)
	if len(data) > 0 {
		p = unsafe.Pointer(&data[0])
	}
	C.glTexImage2D(target.c(), C.GLint(level), C.GLint(format), C.GLsizei(width), C.GLsizei(height), 0, format.c(), ty.c(), p)
}

// TexSubImage2D writes a subregion of a 2D texture image.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexSubImage2D.xhtml
func TexSubImage2D(target Enum, level int, x, y, width, height int, format, ty Enum, data []byte) {
	// TODO(crawshaw): GLES3 offset for PIXEL_UNPACK_BUFFER and PIXEL_PACK_BUFFER.
	C.glTexSubImage2D(target.c(), C.GLint(level), C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height), format.c(), ty.c(), unsafe.Pointer(&data[0]))
}

// TexParameterf sets a float texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameterf(target, pname Enum, param float32) {
	C.glTexParameterf(target.c(), pname.c(), C.GLfloat(param))
}

// TexParameterfv sets a float texture parameter array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameterfv(target, pname Enum, params []float32) {
	C.glTexParameterfv(target.c(), pname.c(), (*C.GLfloat)(&params[0]))
}

// TexParameteri sets an integer texture parameter.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameteri(target, pname Enum, param int) {
	C.glTexParameteri(target.c(), pname.c(), C.GLint(param))
}

// TexParameteriv sets an integer texture parameter array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glTexParameter.xhtml
func TexParameteriv(target, pname Enum, params []int32) {
	C.glTexParameteriv(target.c(), pname.c(), (*C.GLint)(&params[0]))
}

// Uniform1f writes a float uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1f(dst Uniform, v float32) {
	C.glUniform1f(dst.c(), C.GLfloat(v))
}

// Uniform1fv writes a [len(src)]float uniform array.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1fv(dst Uniform, src []float32) {
	C.glUniform1fv(dst.c(), C.GLsizei(len(src)), (*C.GLfloat)(&src[0]))
}

// Uniform1i writes an int uniform variable.
//
// Uniform1i and Uniform1iv are the only two functions that may be used
// to load uniform variables defined as sampler types. Loading samplers
// with any other function will result in a INVALID_OPERATION error.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1i(dst Uniform, v int) {
	C.glUniform1i(dst.c(), C.GLint(v))
}

// Uniform1iv writes a int uniform array of len(src) elements.
//
// Uniform1i and Uniform1iv are the only two functions that may be used
// to load uniform variables defined as sampler types. Loading samplers
// with any other function will result in a INVALID_OPERATION error.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform1iv(dst Uniform, src []int32) {
	C.glUniform1iv(dst.c(), C.GLsizei(len(src)), (*C.GLint)(&src[0]))
}

// Uniform2f writes a vec2 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2f(dst Uniform, v0, v1 float32) {
	C.glUniform2f(dst.c(), C.GLfloat(v0), C.GLfloat(v1))
}

// Uniform2fv writes a vec2 uniform array of len(src)/2 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2fv(dst Uniform, src []float32) {
	C.glUniform2fv(dst.c(), C.GLsizei(len(src)/2), (*C.GLfloat)(&src[0]))
}

// Uniform2i writes an ivec2 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2i(dst Uniform, v0, v1 int) {
	C.glUniform2i(dst.c(), C.GLint(v0), C.GLint(v1))
}

// Uniform2iv writes an ivec2 uniform array of len(src)/2 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform2iv(dst Uniform, src []int32) {
	C.glUniform2iv(dst.c(), C.GLsizei(len(src)/2), (*C.GLint)(&src[0]))
}

// Uniform3f writes a vec3 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3f(dst Uniform, v0, v1, v2 float32) {
	C.glUniform3f(dst.c(), C.GLfloat(v0), C.GLfloat(v1), C.GLfloat(v2))
}

// Uniform3fv writes a vec3 uniform array of len(src)/3 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3fv(dst Uniform, src []float32) {
	C.glUniform3fv(dst.c(), C.GLsizei(len(src)/3), (*C.GLfloat)(&src[0]))
}

// Uniform3i writes an ivec3 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3i(dst Uniform, v0, v1, v2 int32) {
	C.glUniform3i(dst.c(), C.GLint(v0), C.GLint(v1), C.GLint(v2))
}

// Uniform3iv writes an ivec3 uniform array of len(src)/3 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform3iv(dst Uniform, src []int32) {
	C.glUniform3iv(dst.c(), C.GLsizei(len(src)/3), (*C.GLint)(&src[0]))
}

// Uniform4f writes a vec4 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4f(dst Uniform, v0, v1, v2, v3 float32) {
	C.glUniform4f(dst.c(), C.GLfloat(v0), C.GLfloat(v1), C.GLfloat(v2), C.GLfloat(v3))
}

// Uniform4fv writes a vec4 uniform array of len(src)/4 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4fv(dst Uniform, src []float32) {
	C.glUniform4fv(dst.c(), C.GLsizei(len(src)/4), (*C.GLfloat)(&src[0]))
}

// Uniform4i writes an ivec4 uniform variable.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4i(dst Uniform, v0, v1, v2, v3 int32) {
	C.glUniform4i(dst.c(), C.GLint(v0), C.GLint(v1), C.GLint(v2), C.GLint(v3))
}

// Uniform4i writes an ivec4 uniform array of len(src)/4 elements.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func Uniform4iv(dst Uniform, src []int32) {
	C.glUniform4iv(dst.c(), C.GLsizei(len(src)/4), (*C.GLint)(&src[0]))
}

// UniformMatrix2fv writes 2x2 matrices. Each matrix uses four
// float32 values, so the number of matrices written is len(src)/4.
//
// Each matrix must be supplied in column major order.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func UniformMatrix2fv(dst Uniform, src []float32) {
	/// OpenGL ES 2 does not support transpose.
	C.glUniformMatrix2fv(dst.c(), C.GLsizei(len(src)/4), 0, (*C.GLfloat)(&src[0]))
}

// UniformMatrix3fv writes 3x3 matrices. Each matrix uses nine
// float32 values, so the number of matrices written is len(src)/9.
//
// Each matrix must be supplied in column major order.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func UniformMatrix3fv(dst Uniform, src []float32) {
	C.glUniformMatrix3fv(dst.c(), C.GLsizei(len(src)/9), 0, (*C.GLfloat)(&src[0]))
}

// UniformMatrix4fv writes 4x4 matrices. Each matrix uses 16
// float32 values, so the number of matrices written is len(src)/16.
//
// Each matrix must be supplied in column major order.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUniform.xhtml
func UniformMatrix4fv(dst Uniform, src []float32) {
	C.glUniformMatrix4fv(dst.c(), C.GLsizei(len(src)/16), 0, (*C.GLfloat)(&src[0]))
}

// UseProgram sets the active program.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glUseProgram.xhtml
func UseProgram(p Program) {
	C.glUseProgram(p.c())
}

// ValidateProgram checks to see whether the executables contained in
// program can execute given the current OpenGL state.
//
// Typically only used for debugging.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glValidateProgram.xhtml
func ValidateProgram(p Program) {
	C.glValidateProgram(p.c())
}

// VertexAttrib1f writes a float vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib1f(dst Attrib, x float32) {
	C.glVertexAttrib1f(dst.c(), C.GLfloat(x))
}

// VertexAttrib1fv writes a float vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib1fv(dst Attrib, src []float32) {
	C.glVertexAttrib1fv(dst.c(), (*C.GLfloat)(&src[0]))
}

// VertexAttrib2f writes a vec2 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib2f(dst Attrib, x, y float32) {
	C.glVertexAttrib2f(dst.c(), C.GLfloat(x), C.GLfloat(y))
}

// VertexAttrib2fv writes a vec2 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib2fv(dst Attrib, src []float32) {
	C.glVertexAttrib2fv(dst.c(), (*C.GLfloat)(&src[0]))
}

// VertexAttrib3f writes a vec3 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib3f(dst Attrib, x, y, z float32) {
	C.glVertexAttrib3f(dst.c(), C.GLfloat(x), C.GLfloat(y), C.GLfloat(z))
}

// VertexAttrib3fv writes a vec3 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib3fv(dst Attrib, src []float32) {
	C.glVertexAttrib3fv(dst.c(), (*C.GLfloat)(&src[0]))
}

// VertexAttrib4f writes a vec4 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib4f(dst Attrib, x, y, z, w float32) {
	C.glVertexAttrib4f(dst.c(), C.GLfloat(x), C.GLfloat(y), C.GLfloat(z), C.GLfloat(w))
}

// VertexAttrib4fv writes a vec4 vertex attribute.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glVertexAttrib.xhtml
func VertexAttrib4fv(dst Attrib, src []float32) {
	C.glVertexAttrib4fv(dst.c(), (*C.GLfloat)(&src[0]))
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
	n := glBoolean(normalized)
	s := C.GLsizei(stride)
	C.glVertexAttribPointer(dst.c(), C.GLint(size), ty.c(), n, s, unsafe.Pointer(uintptr(offset)))
}

// Viewport sets the viewport, an affine transformation that
// normalizes device coordinates to window coordinates.
//
// http://www.khronos.org/opengles/sdk/docs/man3/html/glViewport.xhtml
func Viewport(x, y, width, height int) {
	C.glViewport(C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height))
}
