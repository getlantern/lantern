// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Generated from gl.go using go generate. DO NOT EDIT.
// See doc.go for details.

// +build linux darwin
// +build gldebug

package gl

/*
#include <stdlib.h>

#ifdef os_linux
#include <GLES2/gl2.h>
#endif
#ifdef os_darwin_arm
#include <OpenGLES/ES2/gl.h>
#endif
#ifdef os_darwin_amd64
#include <OpenGL/gl3.h>
#endif
*/
import "C"

import (
	"fmt"
	"log"
	"unsafe"
)

func errDrain() string {
	var errs []Enum
	for {
		e := Enum(C.glGetError())
		if e == 0 {
			break
		}
		errs = append(errs, e)
	}
	if len(errs) > 0 {
		return fmt.Sprintf(" error: %v", errs)
	}
	return ""
}

func (v Enum) String() string {
	switch v {
	case 0x0:
		return "0"
	case 0x1:
		return "1"
	case 0x2:
		return "LINE_LOOP"
	case 0x3:
		return "LINE_STRIP"
	case 0x4:
		return "TRIANGLES"
	case 0x5:
		return "TRIANGLE_STRIP"
	case 0x6:
		return "TRIANGLE_FAN"
	case 0x300:
		return "SRC_COLOR"
	case 0x301:
		return "ONE_MINUS_SRC_COLOR"
	case 0x302:
		return "SRC_ALPHA"
	case 0x303:
		return "ONE_MINUS_SRC_ALPHA"
	case 0x304:
		return "DST_ALPHA"
	case 0x305:
		return "ONE_MINUS_DST_ALPHA"
	case 0x306:
		return "DST_COLOR"
	case 0x307:
		return "ONE_MINUS_DST_COLOR"
	case 0x308:
		return "SRC_ALPHA_SATURATE"
	case 0x8006:
		return "FUNC_ADD"
	case 0x8009:
		return "32777"
	case 0x883d:
		return "BLEND_EQUATION_ALPHA"
	case 0x800a:
		return "FUNC_SUBTRACT"
	case 0x800b:
		return "FUNC_REVERSE_SUBTRACT"
	case 0x80c8:
		return "BLEND_DST_RGB"
	case 0x80c9:
		return "BLEND_SRC_RGB"
	case 0x80ca:
		return "BLEND_DST_ALPHA"
	case 0x80cb:
		return "BLEND_SRC_ALPHA"
	case 0x8001:
		return "CONSTANT_COLOR"
	case 0x8002:
		return "ONE_MINUS_CONSTANT_COLOR"
	case 0x8003:
		return "CONSTANT_ALPHA"
	case 0x8004:
		return "ONE_MINUS_CONSTANT_ALPHA"
	case 0x8005:
		return "BLEND_COLOR"
	case 0x8892:
		return "ARRAY_BUFFER"
	case 0x8893:
		return "ELEMENT_ARRAY_BUFFER"
	case 0x8894:
		return "ARRAY_BUFFER_BINDING"
	case 0x8895:
		return "ELEMENT_ARRAY_BUFFER_BINDING"
	case 0x88e0:
		return "STREAM_DRAW"
	case 0x88e4:
		return "STATIC_DRAW"
	case 0x88e8:
		return "DYNAMIC_DRAW"
	case 0x8764:
		return "BUFFER_SIZE"
	case 0x8765:
		return "BUFFER_USAGE"
	case 0x8626:
		return "CURRENT_VERTEX_ATTRIB"
	case 0x404:
		return "FRONT"
	case 0x405:
		return "BACK"
	case 0x408:
		return "FRONT_AND_BACK"
	case 0xde1:
		return "TEXTURE_2D"
	case 0xb44:
		return "CULL_FACE"
	case 0xbe2:
		return "BLEND"
	case 0xbd0:
		return "DITHER"
	case 0xb90:
		return "STENCIL_TEST"
	case 0xb71:
		return "DEPTH_TEST"
	case 0xc11:
		return "SCISSOR_TEST"
	case 0x8037:
		return "POLYGON_OFFSET_FILL"
	case 0x809e:
		return "SAMPLE_ALPHA_TO_COVERAGE"
	case 0x80a0:
		return "SAMPLE_COVERAGE"
	case 0x500:
		return "INVALID_ENUM"
	case 0x501:
		return "INVALID_VALUE"
	case 0x502:
		return "INVALID_OPERATION"
	case 0x505:
		return "OUT_OF_MEMORY"
	case 0x900:
		return "CW"
	case 0x901:
		return "CCW"
	case 0xb21:
		return "LINE_WIDTH"
	case 0x846d:
		return "ALIASED_POINT_SIZE_RANGE"
	case 0x846e:
		return "ALIASED_LINE_WIDTH_RANGE"
	case 0xb45:
		return "CULL_FACE_MODE"
	case 0xb46:
		return "FRONT_FACE"
	case 0xb70:
		return "DEPTH_RANGE"
	case 0xb72:
		return "DEPTH_WRITEMASK"
	case 0xb73:
		return "DEPTH_CLEAR_VALUE"
	case 0xb74:
		return "DEPTH_FUNC"
	case 0xb91:
		return "STENCIL_CLEAR_VALUE"
	case 0xb92:
		return "STENCIL_FUNC"
	case 0xb94:
		return "STENCIL_FAIL"
	case 0xb95:
		return "STENCIL_PASS_DEPTH_FAIL"
	case 0xb96:
		return "STENCIL_PASS_DEPTH_PASS"
	case 0xb97:
		return "STENCIL_REF"
	case 0xb93:
		return "STENCIL_VALUE_MASK"
	case 0xb98:
		return "STENCIL_WRITEMASK"
	case 0x8800:
		return "STENCIL_BACK_FUNC"
	case 0x8801:
		return "STENCIL_BACK_FAIL"
	case 0x8802:
		return "STENCIL_BACK_PASS_DEPTH_FAIL"
	case 0x8803:
		return "STENCIL_BACK_PASS_DEPTH_PASS"
	case 0x8ca3:
		return "STENCIL_BACK_REF"
	case 0x8ca4:
		return "STENCIL_BACK_VALUE_MASK"
	case 0x8ca5:
		return "STENCIL_BACK_WRITEMASK"
	case 0xba2:
		return "VIEWPORT"
	case 0xc10:
		return "SCISSOR_BOX"
	case 0xc22:
		return "COLOR_CLEAR_VALUE"
	case 0xc23:
		return "COLOR_WRITEMASK"
	case 0xcf5:
		return "UNPACK_ALIGNMENT"
	case 0xd05:
		return "PACK_ALIGNMENT"
	case 0xd33:
		return "MAX_TEXTURE_SIZE"
	case 0xd3a:
		return "MAX_VIEWPORT_DIMS"
	case 0xd50:
		return "SUBPIXEL_BITS"
	case 0xd52:
		return "RED_BITS"
	case 0xd53:
		return "GREEN_BITS"
	case 0xd54:
		return "BLUE_BITS"
	case 0xd55:
		return "ALPHA_BITS"
	case 0xd56:
		return "DEPTH_BITS"
	case 0xd57:
		return "STENCIL_BITS"
	case 0x2a00:
		return "POLYGON_OFFSET_UNITS"
	case 0x8038:
		return "POLYGON_OFFSET_FACTOR"
	case 0x8069:
		return "TEXTURE_BINDING_2D"
	case 0x80a8:
		return "SAMPLE_BUFFERS"
	case 0x80a9:
		return "SAMPLES"
	case 0x80aa:
		return "SAMPLE_COVERAGE_VALUE"
	case 0x80ab:
		return "SAMPLE_COVERAGE_INVERT"
	case 0x86a2:
		return "NUM_COMPRESSED_TEXTURE_FORMATS"
	case 0x86a3:
		return "COMPRESSED_TEXTURE_FORMATS"
	case 0x1100:
		return "DONT_CARE"
	case 0x1101:
		return "FASTEST"
	case 0x1102:
		return "NICEST"
	case 0x8192:
		return "GENERATE_MIPMAP_HINT"
	case 0x1400:
		return "BYTE"
	case 0x1401:
		return "UNSIGNED_BYTE"
	case 0x1402:
		return "SHORT"
	case 0x1403:
		return "UNSIGNED_SHORT"
	case 0x1404:
		return "INT"
	case 0x1405:
		return "UNSIGNED_INT"
	case 0x1406:
		return "FLOAT"
	case 0x140c:
		return "FIXED"
	case 0x1902:
		return "DEPTH_COMPONENT"
	case 0x1906:
		return "ALPHA"
	case 0x1907:
		return "RGB"
	case 0x1908:
		return "RGBA"
	case 0x1909:
		return "LUMINANCE"
	case 0x190a:
		return "LUMINANCE_ALPHA"
	case 0x8033:
		return "UNSIGNED_SHORT_4_4_4_4"
	case 0x8034:
		return "UNSIGNED_SHORT_5_5_5_1"
	case 0x8363:
		return "UNSIGNED_SHORT_5_6_5"
	case 0x8869:
		return "MAX_VERTEX_ATTRIBS"
	case 0x8dfb:
		return "MAX_VERTEX_UNIFORM_VECTORS"
	case 0x8dfc:
		return "MAX_VARYING_VECTORS"
	case 0x8b4d:
		return "MAX_COMBINED_TEXTURE_IMAGE_UNITS"
	case 0x8b4c:
		return "MAX_VERTEX_TEXTURE_IMAGE_UNITS"
	case 0x8872:
		return "MAX_TEXTURE_IMAGE_UNITS"
	case 0x8dfd:
		return "MAX_FRAGMENT_UNIFORM_VECTORS"
	case 0x8b4f:
		return "SHADER_TYPE"
	case 0x8b80:
		return "DELETE_STATUS"
	case 0x8b82:
		return "LINK_STATUS"
	case 0x8b83:
		return "VALIDATE_STATUS"
	case 0x8b85:
		return "ATTACHED_SHADERS"
	case 0x8b86:
		return "ACTIVE_UNIFORMS"
	case 0x8b87:
		return "ACTIVE_UNIFORM_MAX_LENGTH"
	case 0x8b89:
		return "ACTIVE_ATTRIBUTES"
	case 0x8b8a:
		return "ACTIVE_ATTRIBUTE_MAX_LENGTH"
	case 0x8b8c:
		return "SHADING_LANGUAGE_VERSION"
	case 0x8b8d:
		return "CURRENT_PROGRAM"
	case 0x200:
		return "NEVER"
	case 0x201:
		return "LESS"
	case 0x202:
		return "EQUAL"
	case 0x203:
		return "LEQUAL"
	case 0x204:
		return "GREATER"
	case 0x205:
		return "NOTEQUAL"
	case 0x206:
		return "GEQUAL"
	case 0x207:
		return "ALWAYS"
	case 0x1e00:
		return "KEEP"
	case 0x1e01:
		return "REPLACE"
	case 0x1e02:
		return "INCR"
	case 0x1e03:
		return "DECR"
	case 0x150a:
		return "INVERT"
	case 0x8507:
		return "INCR_WRAP"
	case 0x8508:
		return "DECR_WRAP"
	case 0x1f00:
		return "VENDOR"
	case 0x1f01:
		return "RENDERER"
	case 0x1f02:
		return "VERSION"
	case 0x1f03:
		return "EXTENSIONS"
	case 0x2600:
		return "NEAREST"
	case 0x2601:
		return "LINEAR"
	case 0x2700:
		return "NEAREST_MIPMAP_NEAREST"
	case 0x2701:
		return "LINEAR_MIPMAP_NEAREST"
	case 0x2702:
		return "NEAREST_MIPMAP_LINEAR"
	case 0x2703:
		return "LINEAR_MIPMAP_LINEAR"
	case 0x2800:
		return "TEXTURE_MAG_FILTER"
	case 0x2801:
		return "TEXTURE_MIN_FILTER"
	case 0x2802:
		return "TEXTURE_WRAP_S"
	case 0x2803:
		return "TEXTURE_WRAP_T"
	case 0x1702:
		return "TEXTURE"
	case 0x8513:
		return "TEXTURE_CUBE_MAP"
	case 0x8514:
		return "TEXTURE_BINDING_CUBE_MAP"
	case 0x8515:
		return "TEXTURE_CUBE_MAP_POSITIVE_X"
	case 0x8516:
		return "TEXTURE_CUBE_MAP_NEGATIVE_X"
	case 0x8517:
		return "TEXTURE_CUBE_MAP_POSITIVE_Y"
	case 0x8518:
		return "TEXTURE_CUBE_MAP_NEGATIVE_Y"
	case 0x8519:
		return "TEXTURE_CUBE_MAP_POSITIVE_Z"
	case 0x851a:
		return "TEXTURE_CUBE_MAP_NEGATIVE_Z"
	case 0x851c:
		return "MAX_CUBE_MAP_TEXTURE_SIZE"
	case 0x84c0:
		return "TEXTURE0"
	case 0x84c1:
		return "TEXTURE1"
	case 0x84c2:
		return "TEXTURE2"
	case 0x84c3:
		return "TEXTURE3"
	case 0x84c4:
		return "TEXTURE4"
	case 0x84c5:
		return "TEXTURE5"
	case 0x84c6:
		return "TEXTURE6"
	case 0x84c7:
		return "TEXTURE7"
	case 0x84c8:
		return "TEXTURE8"
	case 0x84c9:
		return "TEXTURE9"
	case 0x84ca:
		return "TEXTURE10"
	case 0x84cb:
		return "TEXTURE11"
	case 0x84cc:
		return "TEXTURE12"
	case 0x84cd:
		return "TEXTURE13"
	case 0x84ce:
		return "TEXTURE14"
	case 0x84cf:
		return "TEXTURE15"
	case 0x84d0:
		return "TEXTURE16"
	case 0x84d1:
		return "TEXTURE17"
	case 0x84d2:
		return "TEXTURE18"
	case 0x84d3:
		return "TEXTURE19"
	case 0x84d4:
		return "TEXTURE20"
	case 0x84d5:
		return "TEXTURE21"
	case 0x84d6:
		return "TEXTURE22"
	case 0x84d7:
		return "TEXTURE23"
	case 0x84d8:
		return "TEXTURE24"
	case 0x84d9:
		return "TEXTURE25"
	case 0x84da:
		return "TEXTURE26"
	case 0x84db:
		return "TEXTURE27"
	case 0x84dc:
		return "TEXTURE28"
	case 0x84dd:
		return "TEXTURE29"
	case 0x84de:
		return "TEXTURE30"
	case 0x84df:
		return "TEXTURE31"
	case 0x84e0:
		return "ACTIVE_TEXTURE"
	case 0x2901:
		return "REPEAT"
	case 0x812f:
		return "CLAMP_TO_EDGE"
	case 0x8370:
		return "MIRRORED_REPEAT"
	case 0x8622:
		return "VERTEX_ATTRIB_ARRAY_ENABLED"
	case 0x8623:
		return "VERTEX_ATTRIB_ARRAY_SIZE"
	case 0x8624:
		return "VERTEX_ATTRIB_ARRAY_STRIDE"
	case 0x8625:
		return "VERTEX_ATTRIB_ARRAY_TYPE"
	case 0x886a:
		return "VERTEX_ATTRIB_ARRAY_NORMALIZED"
	case 0x8645:
		return "VERTEX_ATTRIB_ARRAY_POINTER"
	case 0x889f:
		return "VERTEX_ATTRIB_ARRAY_BUFFER_BINDING"
	case 0x8b9a:
		return "IMPLEMENTATION_COLOR_READ_TYPE"
	case 0x8b9b:
		return "IMPLEMENTATION_COLOR_READ_FORMAT"
	case 0x8b81:
		return "COMPILE_STATUS"
	case 0x8b84:
		return "INFO_LOG_LENGTH"
	case 0x8b88:
		return "SHADER_SOURCE_LENGTH"
	case 0x8dfa:
		return "SHADER_COMPILER"
	case 0x8df8:
		return "SHADER_BINARY_FORMATS"
	case 0x8df9:
		return "NUM_SHADER_BINARY_FORMATS"
	case 0x8df0:
		return "LOW_FLOAT"
	case 0x8df1:
		return "MEDIUM_FLOAT"
	case 0x8df2:
		return "HIGH_FLOAT"
	case 0x8df3:
		return "LOW_INT"
	case 0x8df4:
		return "MEDIUM_INT"
	case 0x8df5:
		return "HIGH_INT"
	case 0x8d40:
		return "FRAMEBUFFER"
	case 0x8d41:
		return "RENDERBUFFER"
	case 0x8056:
		return "RGBA4"
	case 0x8057:
		return "RGB5_A1"
	case 0x8d62:
		return "RGB565"
	case 0x81a5:
		return "DEPTH_COMPONENT16"
	case 0x8d48:
		return "STENCIL_INDEX8"
	case 0x8d42:
		return "RENDERBUFFER_WIDTH"
	case 0x8d43:
		return "RENDERBUFFER_HEIGHT"
	case 0x8d44:
		return "RENDERBUFFER_INTERNAL_FORMAT"
	case 0x8d50:
		return "RENDERBUFFER_RED_SIZE"
	case 0x8d51:
		return "RENDERBUFFER_GREEN_SIZE"
	case 0x8d52:
		return "RENDERBUFFER_BLUE_SIZE"
	case 0x8d53:
		return "RENDERBUFFER_ALPHA_SIZE"
	case 0x8d54:
		return "RENDERBUFFER_DEPTH_SIZE"
	case 0x8d55:
		return "RENDERBUFFER_STENCIL_SIZE"
	case 0x8cd0:
		return "FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE"
	case 0x8cd1:
		return "FRAMEBUFFER_ATTACHMENT_OBJECT_NAME"
	case 0x8cd2:
		return "FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL"
	case 0x8cd3:
		return "FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE"
	case 0x8ce0:
		return "COLOR_ATTACHMENT0"
	case 0x8d00:
		return "DEPTH_ATTACHMENT"
	case 0x8d20:
		return "STENCIL_ATTACHMENT"
	case 0x8cd5:
		return "FRAMEBUFFER_COMPLETE"
	case 0x8cd6:
		return "FRAMEBUFFER_INCOMPLETE_ATTACHMENT"
	case 0x8cd7:
		return "FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT"
	case 0x8cd9:
		return "FRAMEBUFFER_INCOMPLETE_DIMENSIONS"
	case 0x8cdd:
		return "FRAMEBUFFER_UNSUPPORTED"
	case 0x8ca6:
		return "FRAMEBUFFER_BINDING"
	case 0x8ca7:
		return "RENDERBUFFER_BINDING"
	case 0x84e8:
		return "MAX_RENDERBUFFER_SIZE"
	case 0x506:
		return "INVALID_FRAMEBUFFER_OPERATION"
	case 0x100:
		return "DEPTH_BUFFER_BIT"
	case 0x400:
		return "STENCIL_BUFFER_BIT"
	case 0x4000:
		return "COLOR_BUFFER_BIT"
	case 0x8b50:
		return "FLOAT_VEC2"
	case 0x8b51:
		return "FLOAT_VEC3"
	case 0x8b52:
		return "FLOAT_VEC4"
	case 0x8b53:
		return "INT_VEC2"
	case 0x8b54:
		return "INT_VEC3"
	case 0x8b55:
		return "INT_VEC4"
	case 0x8b56:
		return "BOOL"
	case 0x8b57:
		return "BOOL_VEC2"
	case 0x8b58:
		return "BOOL_VEC3"
	case 0x8b59:
		return "BOOL_VEC4"
	case 0x8b5a:
		return "FLOAT_MAT2"
	case 0x8b5b:
		return "FLOAT_MAT3"
	case 0x8b5c:
		return "FLOAT_MAT4"
	case 0x8b5e:
		return "SAMPLER_2D"
	case 0x8b60:
		return "SAMPLER_CUBE"
	case 0x8b30:
		return "FRAGMENT_SHADER"
	case 0x8b31:
		return "VERTEX_SHADER"
	default:
		return fmt.Sprintf("gl.Enum(0x%x)", uint32(v))
	}
}

func ActiveTexture(texture Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ActiveTexture(%v) %v", texture, errstr)
	}()
	C.glActiveTexture(texture.c())
}

func AttachShader(p Program, s Shader) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.AttachShader(%v, %v) %v", p, s, errstr)
	}()
	C.glAttachShader(p.c(), s.c())
}

func BindAttribLocation(p Program, a Attrib, name string) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BindAttribLocation(%v, %v, %v) %v", p, a, name, errstr)
	}()
	str := unsafe.Pointer(C.CString(name))
	defer C.free(str)
	C.glBindAttribLocation(p.c(), a.c(), (*C.GLchar)(str))
}

func BindBuffer(target Enum, b Buffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BindBuffer(%v, %v) %v", target, b, errstr)
	}()
	C.glBindBuffer(target.c(), b.c())
}

func BindFramebuffer(target Enum, fb Framebuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BindFramebuffer(%v, %v) %v", target, fb, errstr)
	}()
	C.glBindFramebuffer(target.c(), fb.c())
}

func BindRenderbuffer(target Enum, rb Renderbuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BindRenderbuffer(%v, %v) %v", target, rb, errstr)
	}()
	C.glBindRenderbuffer(target.c(), rb.c())
}

func BindTexture(target Enum, t Texture) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BindTexture(%v, %v) %v", target, t, errstr)
	}()
	C.glBindTexture(target.c(), t.c())
}

func BlendColor(red, green, blue, alpha float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BlendColor(%v, %v, %v, %v) %v", red, green, blue, alpha, errstr)
	}()
	blendColor(red, green, blue, alpha)
}

func BlendEquation(mode Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BlendEquation(%v) %v", mode, errstr)
	}()
	C.glBlendEquation(mode.c())
}

func BlendEquationSeparate(modeRGB, modeAlpha Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BlendEquationSeparate(%v, %v) %v", modeRGB, modeAlpha, errstr)
	}()
	C.glBlendEquationSeparate(modeRGB.c(), modeAlpha.c())
}

func BlendFunc(sfactor, dfactor Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BlendFunc(%v, %v) %v", sfactor, dfactor, errstr)
	}()
	C.glBlendFunc(sfactor.c(), dfactor.c())
}

func BlendFuncSeparate(sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BlendFuncSeparate(%v, %v, %v, %v) %v", sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha, errstr)
	}()
	C.glBlendFuncSeparate(sfactorRGB.c(), dfactorRGB.c(), sfactorAlpha.c(), dfactorAlpha.c())
}

func BufferData(target Enum, src []byte, usage Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BufferData(%v, len(%d), %v) %v", target, len(src), usage, errstr)
	}()
	C.glBufferData(target.c(), C.GLsizeiptr(len(src)), unsafe.Pointer(&src[0]), usage.c())
}

func BufferInit(target Enum, size int, usage Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BufferInit(%v, %v, %v) %v", target, size, usage, errstr)
	}()
	C.glBufferData(target.c(), C.GLsizeiptr(size), nil, usage.c())
}

func BufferSubData(target Enum, offset int, data []byte) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.BufferSubData(%v, %v, len(%d)) %v", target, offset, len(data), errstr)
	}()
	C.glBufferSubData(target.c(), C.GLintptr(offset), C.GLsizeiptr(len(data)), unsafe.Pointer(&data[0]))
}

func CheckFramebufferStatus(target Enum) (r0 Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CheckFramebufferStatus(%v) %v%v", target, r0, errstr)
	}()
	return Enum(C.glCheckFramebufferStatus(target.c()))
}

func Clear(mask Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Clear(%v) %v", mask, errstr)
	}()
	C.glClear(C.GLbitfield(mask))
}

func ClearColor(red, green, blue, alpha float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ClearColor(%v, %v, %v, %v) %v", red, green, blue, alpha, errstr)
	}()
	clearColor(red, green, blue, alpha)
}

func ClearDepthf(d float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ClearDepthf(%v) %v", d, errstr)
	}()
	clearDepthf(d)
}

func ClearStencil(s int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ClearStencil(%v) %v", s, errstr)
	}()
	C.glClearStencil(C.GLint(s))
}

func ColorMask(red, green, blue, alpha bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ColorMask(%v, %v, %v, %v) %v", red, green, blue, alpha, errstr)
	}()
	C.glColorMask(glBoolean(red), glBoolean(green), glBoolean(blue), glBoolean(alpha))
}

func CompileShader(s Shader) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CompileShader(%v) %v", s, errstr)
	}()
	C.glCompileShader(s.c())
}

func CompressedTexImage2D(target Enum, level int, internalformat Enum, width, height, border int, data []byte) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CompressedTexImage2D(%v, %v, %v, %v, %v, %v, len(%d)) %v", target, level, internalformat, width, height, border, len(data), errstr)
	}()
	C.glCompressedTexImage2D(target.c(), C.GLint(level), internalformat.c(), C.GLsizei(width), C.GLsizei(height), C.GLint(border), C.GLsizei(len(data)), unsafe.Pointer(&data[0]))
}

func CompressedTexSubImage2D(target Enum, level, xoffset, yoffset, width, height int, format Enum, data []byte) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CompressedTexSubImage2D(%v, %v, %v, %v, %v, %v, %v, len(%d)) %v", target, level, xoffset, yoffset, width, height, format, len(data), errstr)
	}()
	C.glCompressedTexSubImage2D(target.c(), C.GLint(level), C.GLint(xoffset), C.GLint(yoffset), C.GLsizei(width), C.GLsizei(height), format.c(), C.GLsizei(len(data)), unsafe.Pointer(&data[0]))
}

func CopyTexImage2D(target Enum, level int, internalformat Enum, x, y, width, height, border int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CopyTexImage2D(%v, %v, %v, %v, %v, %v, %v, %v) %v", target, level, internalformat, x, y, width, height, border, errstr)
	}()
	C.glCopyTexImage2D(target.c(), C.GLint(level), internalformat.c(), C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height), C.GLint(border))
}

func CopyTexSubImage2D(target Enum, level, xoffset, yoffset, x, y, width, height int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CopyTexSubImage2D(%v, %v, %v, %v, %v, %v, %v, %v) %v", target, level, xoffset, yoffset, x, y, width, height, errstr)
	}()
	C.glCopyTexSubImage2D(target.c(), C.GLint(level), C.GLint(xoffset), C.GLint(yoffset), C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height))
}

func CreateBuffer() (r0 Buffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CreateBuffer() %v%v", r0, errstr)
	}()
	var b Buffer
	C.glGenBuffers(1, (*C.GLuint)(&b.Value))
	return b
}

func CreateFramebuffer() (r0 Framebuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CreateFramebuffer() %v%v", r0, errstr)
	}()
	var b Framebuffer
	C.glGenFramebuffers(1, (*C.GLuint)(&b.Value))
	return b
}

func CreateProgram() (r0 Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CreateProgram() %v%v", r0, errstr)
	}()
	return Program{Value: uint32(C.glCreateProgram())}
}

func CreateRenderbuffer() (r0 Renderbuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CreateRenderbuffer() %v%v", r0, errstr)
	}()
	var b Renderbuffer
	C.glGenRenderbuffers(1, (*C.GLuint)(&b.Value))
	return b
}

func CreateShader(ty Enum) (r0 Shader) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CreateShader(%v) %v%v", ty, r0, errstr)
	}()
	return Shader{Value: uint32(C.glCreateShader(ty.c()))}
}

func CreateTexture() (r0 Texture) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CreateTexture() %v%v", r0, errstr)
	}()
	var t Texture
	C.glGenTextures(1, (*C.GLuint)(&t.Value))
	return t
}

func CullFace(mode Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.CullFace(%v) %v", mode, errstr)
	}()
	C.glCullFace(mode.c())
}

func DeleteBuffer(v Buffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DeleteBuffer(%v) %v", v, errstr)
	}()
	C.glDeleteBuffers(1, (*C.GLuint)(&v.Value))
}

func DeleteFramebuffer(v Framebuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DeleteFramebuffer(%v) %v", v, errstr)
	}()
	C.glDeleteFramebuffers(1, (*C.GLuint)(&v.Value))
}

func DeleteProgram(p Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DeleteProgram(%v) %v", p, errstr)
	}()
	C.glDeleteProgram(p.c())
}

func DeleteRenderbuffer(v Renderbuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DeleteRenderbuffer(%v) %v", v, errstr)
	}()
	C.glDeleteRenderbuffers(1, (*C.GLuint)(&v.Value))
}

func DeleteShader(s Shader) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DeleteShader(%v) %v", s, errstr)
	}()
	C.glDeleteShader(s.c())
}

func DeleteTexture(v Texture) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DeleteTexture(%v) %v", v, errstr)
	}()
	C.glDeleteTextures(1, (*C.GLuint)(&v.Value))
}

func DepthFunc(fn Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DepthFunc(%v) %v", fn, errstr)
	}()
	C.glDepthFunc(fn.c())
}

func DepthMask(flag bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DepthMask(%v) %v", flag, errstr)
	}()
	C.glDepthMask(glBoolean(flag))
}

func DepthRangef(n, f float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DepthRangef(%v, %v) %v", n, f, errstr)
	}()
	depthRangef(n, f)
}

func DetachShader(p Program, s Shader) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DetachShader(%v, %v) %v", p, s, errstr)
	}()
	C.glDetachShader(p.c(), s.c())
}

func Disable(cap Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Disable(%v) %v", cap, errstr)
	}()
	C.glDisable(cap.c())
}

func DisableVertexAttribArray(a Attrib) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DisableVertexAttribArray(%v) %v", a, errstr)
	}()
	C.glDisableVertexAttribArray(a.c())
}

func DrawArrays(mode Enum, first, count int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DrawArrays(%v, %v, %v) %v", mode, first, count, errstr)
	}()
	C.glDrawArrays(mode.c(), C.GLint(first), C.GLsizei(count))
}

func DrawElements(mode Enum, count int, ty Enum, offset int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.DrawElements(%v, %v, %v, %v) %v", mode, count, ty, offset, errstr)
	}()
	C.glDrawElements(mode.c(), C.GLsizei(count), ty.c(), unsafe.Pointer(uintptr(offset)))
}

func Enable(cap Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Enable(%v) %v", cap, errstr)
	}()
	C.glEnable(cap.c())
}

func EnableVertexAttribArray(a Attrib) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.EnableVertexAttribArray(%v) %v", a, errstr)
	}()
	C.glEnableVertexAttribArray(a.c())
}

func Finish() {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Finish() %v", errstr)
	}()
	C.glFinish()
}

func Flush() {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Flush() %v", errstr)
	}()
	C.glFlush()
}

func FramebufferRenderbuffer(target, attachment, rbTarget Enum, rb Renderbuffer) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.FramebufferRenderbuffer(%v, %v, %v, %v) %v", target, attachment, rbTarget, rb, errstr)
	}()
	C.glFramebufferRenderbuffer(target.c(), attachment.c(), rbTarget.c(), rb.c())
}

func FramebufferTexture2D(target, attachment, texTarget Enum, t Texture, level int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.FramebufferTexture2D(%v, %v, %v, %v, %v) %v", target, attachment, texTarget, t, level, errstr)
	}()
	C.glFramebufferTexture2D(target.c(), attachment.c(), texTarget.c(), t.c(), C.GLint(level))
}

func FrontFace(mode Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.FrontFace(%v) %v", mode, errstr)
	}()
	C.glFrontFace(mode.c())
}

func GenerateMipmap(target Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GenerateMipmap(%v) %v", target, errstr)
	}()
	C.glGenerateMipmap(target.c())
}

func GetActiveAttrib(p Program, index uint32) (name string, size int, ty Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetActiveAttrib(%v, %v) (%v, %v, %v) %v", p, index, name, size, ty, errstr)
	}()
	bufSize := GetProgrami(p, ACTIVE_ATTRIBUTE_MAX_LENGTH)
	buf := C.malloc(C.size_t(bufSize))
	defer C.free(buf)
	var cSize C.GLint
	var cType C.GLenum
	C.glGetActiveAttrib(p.c(), C.GLuint(index), C.GLsizei(bufSize), nil, &cSize, &cType, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf)), int(cSize), Enum(cType)
}

func GetActiveUniform(p Program, index uint32) (name string, size int, ty Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetActiveUniform(%v, %v) (%v, %v, %v) %v", p, index, name, size, ty, errstr)
	}()
	bufSize := GetProgrami(p, ACTIVE_UNIFORM_MAX_LENGTH)
	buf := C.malloc(C.size_t(bufSize))
	defer C.free(buf)
	var cSize C.GLint
	var cType C.GLenum
	C.glGetActiveUniform(p.c(), C.GLuint(index), C.GLsizei(bufSize), nil, &cSize, &cType, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf)), int(cSize), Enum(cType)
}

func GetAttachedShaders(p Program) (r0 []Shader) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetAttachedShaders(%v) %v%v", p, r0, errstr)
	}()
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

func GetAttribLocation(p Program, name string) (r0 Attrib) {
	defer func() {
		errstr := errDrain()
		r0.name = name
		log.Printf("gl.GetAttribLocation(%v, %v) %v%v", p, name, r0, errstr)
	}()
	str := unsafe.Pointer(C.CString(name))
	defer C.free(str)
	return Attrib{Value: uint(C.glGetAttribLocation(p.c(), (*C.GLchar)(str)))}
}

func GetBooleanv(dst []bool, pname Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetBooleanv(%v, %v) %v", dst, pname, errstr)
	}()
	buf := make([]C.GLboolean, len(dst))
	C.glGetBooleanv(pname.c(), &buf[0])
	for i, v := range buf {
		dst[i] = v != 0
	}
}

func GetFloatv(dst []float32, pname Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetFloatv(len(%d), %v) %v", len(dst), pname, errstr)
	}()
	C.glGetFloatv(pname.c(), (*C.GLfloat)(&dst[0]))
}

func GetIntegerv(pname Enum, data []int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetIntegerv(%v, %v) %v", pname, data, errstr)
	}()
	buf := make([]C.GLint, len(data))
	C.glGetIntegerv(pname.c(), &buf[0])
	for i, v := range buf {
		data[i] = int32(v)
	}
}

func GetInteger(pname Enum) (r0 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetInteger(%v) %v%v", pname, r0, errstr)
	}()
	var v C.GLint
	C.glGetIntegerv(pname.c(), &v)
	return int(v)
}

func GetBufferParameteri(target, pname Enum) (r0 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetBufferParameteri(%v, %v) %v%v", target, pname, r0, errstr)
	}()
	var params C.GLint
	C.glGetBufferParameteriv(target.c(), pname.c(), &params)
	return int(params)
}

func GetError() (r0 Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetError() %v%v", r0, errstr)
	}()
	return Enum(C.glGetError())
}

func GetFramebufferAttachmentParameteri(target, attachment, pname Enum) (r0 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetFramebufferAttachmentParameteri(%v, %v, %v) %v%v", target, attachment, pname, r0, errstr)
	}()
	var params C.GLint
	C.glGetFramebufferAttachmentParameteriv(target.c(), attachment.c(), pname.c(), &params)
	return int(params)
}

func GetProgrami(p Program, pname Enum) (r0 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetProgrami(%v, %v) %v%v", p, pname, r0, errstr)
	}()
	var params C.GLint
	C.glGetProgramiv(p.c(), pname.c(), &params)
	return int(params)
}

func GetProgramInfoLog(p Program) (r0 string) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetProgramInfoLog(%v) %v%v", p, r0, errstr)
	}()
	infoLen := GetProgrami(p, INFO_LOG_LENGTH)
	buf := C.malloc(C.size_t(infoLen))
	C.free(buf)
	C.glGetProgramInfoLog(p.c(), C.GLsizei(infoLen), nil, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf))
}

func GetRenderbufferParameteri(target, pname Enum) (r0 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetRenderbufferParameteri(%v, %v) %v%v", target, pname, r0, errstr)
	}()
	var params C.GLint
	C.glGetRenderbufferParameteriv(target.c(), pname.c(), &params)
	return int(params)
}

func GetShaderi(s Shader, pname Enum) (r0 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetShaderi(%v, %v) %v%v", s, pname, r0, errstr)
	}()
	var params C.GLint
	C.glGetShaderiv(s.c(), pname.c(), &params)
	return int(params)
}

func GetShaderInfoLog(s Shader) (r0 string) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetShaderInfoLog(%v) %v%v", s, r0, errstr)
	}()
	infoLen := GetShaderi(s, INFO_LOG_LENGTH)
	buf := C.malloc(C.size_t(infoLen))
	defer C.free(buf)
	C.glGetShaderInfoLog(s.c(), C.GLsizei(infoLen), nil, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf))
}

func GetShaderPrecisionFormat(shadertype, precisiontype Enum) (rangeLow, rangeHigh, precision int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetShaderPrecisionFormat(%v, %v) (%v, %v, %v) %v", shadertype, precisiontype, rangeLow, rangeHigh, precision, errstr)
	}()
	const glintSize = 4
	var cRange [2]C.GLint
	var cPrecision C.GLint
	C.glGetShaderPrecisionFormat(shadertype.c(), precisiontype.c(), &cRange[0], &cPrecision)
	return int(cRange[0]), int(cRange[1]), int(cPrecision)
}

func GetShaderSource(s Shader) (r0 string) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetShaderSource(%v) %v%v", s, r0, errstr)
	}()
	sourceLen := GetShaderi(s, SHADER_SOURCE_LENGTH)
	if sourceLen == 0 {
		return ""
	}
	buf := C.malloc(C.size_t(sourceLen))
	defer C.free(buf)
	C.glGetShaderSource(s.c(), C.GLsizei(sourceLen), nil, (*C.GLchar)(buf))
	return C.GoString((*C.char)(buf))
}

func GetString(pname Enum) (r0 string) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetString(%v) %v%v", pname, r0, errstr)
	}()
	return C.GoString((*C.char)((unsafe.Pointer)(C.glGetString(pname.c()))))
}

func GetTexParameterfv(dst []float32, target, pname Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetTexParameterfv(len(%d), %v, %v) %v", len(dst), target, pname, errstr)
	}()
	C.glGetTexParameterfv(target.c(), pname.c(), (*C.GLfloat)(&dst[0]))
}

func GetTexParameteriv(dst []int32, target, pname Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetTexParameteriv(%v, %v, %v) %v", dst, target, pname, errstr)
	}()
	C.glGetTexParameteriv(target.c(), pname.c(), (*C.GLint)(&dst[0]))
}

func GetUniformfv(dst []float32, src Uniform, p Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetUniformfv(len(%d), %v, %v) %v", len(dst), src, p, errstr)
	}()
	C.glGetUniformfv(p.c(), src.c(), (*C.GLfloat)(&dst[0]))
}

func GetUniformiv(dst []int32, src Uniform, p Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetUniformiv(%v, %v, %v) %v", dst, src, p, errstr)
	}()
	C.glGetUniformiv(p.c(), src.c(), (*C.GLint)(&dst[0]))
}

func GetUniformLocation(p Program, name string) (r0 Uniform) {
	defer func() {
		errstr := errDrain()
		r0.name = name
		log.Printf("gl.GetUniformLocation(%v, %v) %v%v", p, name, r0, errstr)
	}()
	str := unsafe.Pointer(C.CString(name))
	defer C.free(str)
	return Uniform{Value: int32(C.glGetUniformLocation(p.c(), (*C.GLchar)(str)))}
}

func GetVertexAttribf(src Attrib, pname Enum) (r0 float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetVertexAttribf(%v, %v) %v%v", src, pname, r0, errstr)
	}()
	var params C.GLfloat
	C.glGetVertexAttribfv(src.c(), pname.c(), &params)
	return float32(params)
}

func GetVertexAttribfv(dst []float32, src Attrib, pname Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetVertexAttribfv(len(%d), %v, %v) %v", len(dst), src, pname, errstr)
	}()
	C.glGetVertexAttribfv(src.c(), pname.c(), (*C.GLfloat)(&dst[0]))
}

func GetVertexAttribi(src Attrib, pname Enum) (r0 int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetVertexAttribi(%v, %v) %v%v", src, pname, r0, errstr)
	}()
	var params C.GLint
	C.glGetVertexAttribiv(src.c(), pname.c(), &params)
	return int32(params)
}

func GetVertexAttribiv(dst []int32, src Attrib, pname Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.GetVertexAttribiv(%v, %v, %v) %v", dst, src, pname, errstr)
	}()
	C.glGetVertexAttribiv(src.c(), pname.c(), (*C.GLint)(&dst[0]))
}

func Hint(target, mode Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Hint(%v, %v) %v", target, mode, errstr)
	}()
	C.glHint(target.c(), mode.c())
}

func IsBuffer(b Buffer) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsBuffer(%v) %v%v", b, r0, errstr)
	}()
	return C.glIsBuffer(b.c()) != 0
}

func IsEnabled(cap Enum) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsEnabled(%v) %v%v", cap, r0, errstr)
	}()
	return C.glIsEnabled(cap.c()) != 0
}

func IsFramebuffer(fb Framebuffer) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsFramebuffer(%v) %v%v", fb, r0, errstr)
	}()
	return C.glIsFramebuffer(fb.c()) != 0
}

func IsProgram(p Program) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsProgram(%v) %v%v", p, r0, errstr)
	}()
	return C.glIsProgram(p.c()) != 0
}

func IsRenderbuffer(rb Renderbuffer) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsRenderbuffer(%v) %v%v", rb, r0, errstr)
	}()
	return C.glIsRenderbuffer(rb.c()) != 0
}

func IsShader(s Shader) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsShader(%v) %v%v", s, r0, errstr)
	}()
	return C.glIsShader(s.c()) != 0
}

func IsTexture(t Texture) (r0 bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.IsTexture(%v) %v%v", t, r0, errstr)
	}()
	return C.glIsTexture(t.c()) != 0
}

func LineWidth(width float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.LineWidth(%v) %v", width, errstr)
	}()
	C.glLineWidth(C.GLfloat(width))
}

func LinkProgram(p Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.LinkProgram(%v) %v", p, errstr)
	}()
	C.glLinkProgram(p.c())
}

func PixelStorei(pname Enum, param int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.PixelStorei(%v, %v) %v", pname, param, errstr)
	}()
	C.glPixelStorei(pname.c(), C.GLint(param))
}

func PolygonOffset(factor, units float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.PolygonOffset(%v, %v) %v", factor, units, errstr)
	}()
	C.glPolygonOffset(C.GLfloat(factor), C.GLfloat(units))
}

func ReadPixels(dst []byte, x, y, width, height int, format, ty Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ReadPixels(len(%d), %v, %v, %v, %v, %v, %v) %v", len(dst), x, y, width, height, format, ty, errstr)
	}()
	C.glReadPixels(C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height), format.c(), ty.c(), unsafe.Pointer(&dst[0]))
}

func ReleaseShaderCompiler() {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ReleaseShaderCompiler() %v", errstr)
	}()
	C.glReleaseShaderCompiler()
}

func RenderbufferStorage(target, internalFormat Enum, width, height int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.RenderbufferStorage(%v, %v, %v, %v) %v", target, internalFormat, width, height, errstr)
	}()
	C.glRenderbufferStorage(target.c(), internalFormat.c(), C.GLsizei(width), C.GLsizei(height))
}

func SampleCoverage(value float32, invert bool) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.SampleCoverage(%v, %v) %v", value, invert, errstr)
	}()
	sampleCoverage(value, invert)
}

func Scissor(x, y, width, height int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Scissor(%v, %v, %v, %v) %v", x, y, width, height, errstr)
	}()
	C.glScissor(C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height))
}

func ShaderSource(s Shader, src string) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ShaderSource(%v, %v) %v", s, src, errstr)
	}()
	str := (*C.GLchar)(C.CString(src))
	defer C.free(unsafe.Pointer(str))
	C.glShaderSource(s.c(), 1, &str, nil)
}

func StencilFunc(fn Enum, ref int, mask uint32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.StencilFunc(%v, %v, %v) %v", fn, ref, mask, errstr)
	}()
	C.glStencilFunc(fn.c(), C.GLint(ref), C.GLuint(mask))
}

func StencilFuncSeparate(face, fn Enum, ref int, mask uint32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.StencilFuncSeparate(%v, %v, %v, %v) %v", face, fn, ref, mask, errstr)
	}()
	C.glStencilFuncSeparate(face.c(), fn.c(), C.GLint(ref), C.GLuint(mask))
}

func StencilMask(mask uint32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.StencilMask(%v) %v", mask, errstr)
	}()
	C.glStencilMask(C.GLuint(mask))
}

func StencilMaskSeparate(face Enum, mask uint32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.StencilMaskSeparate(%v, %v) %v", face, mask, errstr)
	}()
	C.glStencilMaskSeparate(face.c(), C.GLuint(mask))
}

func StencilOp(fail, zfail, zpass Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.StencilOp(%v, %v, %v) %v", fail, zfail, zpass, errstr)
	}()
	C.glStencilOp(fail.c(), zfail.c(), zpass.c())
}

func StencilOpSeparate(face, sfail, dpfail, dppass Enum) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.StencilOpSeparate(%v, %v, %v, %v) %v", face, sfail, dpfail, dppass, errstr)
	}()
	C.glStencilOpSeparate(face.c(), sfail.c(), dpfail.c(), dppass.c())
}

func TexImage2D(target Enum, level int, width, height int, format Enum, ty Enum, data []byte) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.TexImage2D(%v, %v, %v, %v, %v, %v, len(%d)) %v", target, level, width, height, format, ty, len(data), errstr)
	}()
	p := unsafe.Pointer(nil)
	if len(data) > 0 {
		p = unsafe.Pointer(&data[0])
	}
	C.glTexImage2D(target.c(), C.GLint(level), C.GLint(format), C.GLsizei(width), C.GLsizei(height), 0, format.c(), ty.c(), p)
}

func TexSubImage2D(target Enum, level int, x, y, width, height int, format, ty Enum, data []byte) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.TexSubImage2D(%v, %v, %v, %v, %v, %v, %v, %v, len(%d)) %v", target, level, x, y, width, height, format, ty, len(data), errstr)
	}()
	C.glTexSubImage2D(target.c(), C.GLint(level), C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height), format.c(), ty.c(), unsafe.Pointer(&data[0]))
}

func TexParameterf(target, pname Enum, param float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.TexParameterf(%v, %v, %v) %v", target, pname, param, errstr)
	}()
	C.glTexParameterf(target.c(), pname.c(), C.GLfloat(param))
}

func TexParameterfv(target, pname Enum, params []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.TexParameterfv(%v, %v, len(%d)) %v", target, pname, len(params), errstr)
	}()
	C.glTexParameterfv(target.c(), pname.c(), (*C.GLfloat)(&params[0]))
}

func TexParameteri(target, pname Enum, param int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.TexParameteri(%v, %v, %v) %v", target, pname, param, errstr)
	}()
	C.glTexParameteri(target.c(), pname.c(), C.GLint(param))
}

func TexParameteriv(target, pname Enum, params []int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.TexParameteriv(%v, %v, %v) %v", target, pname, params, errstr)
	}()
	C.glTexParameteriv(target.c(), pname.c(), (*C.GLint)(&params[0]))
}

func Uniform1f(dst Uniform, v float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform1f(%v, %v) %v", dst, v, errstr)
	}()
	C.glUniform1f(dst.c(), C.GLfloat(v))
}

func Uniform1fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform1fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniform1fv(dst.c(), C.GLsizei(len(src)), (*C.GLfloat)(&src[0]))
}

func Uniform1i(dst Uniform, v int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform1i(%v, %v) %v", dst, v, errstr)
	}()
	C.glUniform1i(dst.c(), C.GLint(v))
}

func Uniform1iv(dst Uniform, src []int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform1iv(%v, %v) %v", dst, src, errstr)
	}()
	C.glUniform1iv(dst.c(), C.GLsizei(len(src)), (*C.GLint)(&src[0]))
}

func Uniform2f(dst Uniform, v0, v1 float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform2f(%v, %v, %v) %v", dst, v0, v1, errstr)
	}()
	C.glUniform2f(dst.c(), C.GLfloat(v0), C.GLfloat(v1))
}

func Uniform2fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform2fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniform2fv(dst.c(), C.GLsizei(len(src)/2), (*C.GLfloat)(&src[0]))
}

func Uniform2i(dst Uniform, v0, v1 int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform2i(%v, %v, %v) %v", dst, v0, v1, errstr)
	}()
	C.glUniform2i(dst.c(), C.GLint(v0), C.GLint(v1))
}

func Uniform2iv(dst Uniform, src []int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform2iv(%v, %v) %v", dst, src, errstr)
	}()
	C.glUniform2iv(dst.c(), C.GLsizei(len(src)/2), (*C.GLint)(&src[0]))
}

func Uniform3f(dst Uniform, v0, v1, v2 float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform3f(%v, %v, %v, %v) %v", dst, v0, v1, v2, errstr)
	}()
	C.glUniform3f(dst.c(), C.GLfloat(v0), C.GLfloat(v1), C.GLfloat(v2))
}

func Uniform3fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform3fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniform3fv(dst.c(), C.GLsizei(len(src)/3), (*C.GLfloat)(&src[0]))
}

func Uniform3i(dst Uniform, v0, v1, v2 int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform3i(%v, %v, %v, %v) %v", dst, v0, v1, v2, errstr)
	}()
	C.glUniform3i(dst.c(), C.GLint(v0), C.GLint(v1), C.GLint(v2))
}

func Uniform3iv(dst Uniform, src []int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform3iv(%v, %v) %v", dst, src, errstr)
	}()
	C.glUniform3iv(dst.c(), C.GLsizei(len(src)/3), (*C.GLint)(&src[0]))
}

func Uniform4f(dst Uniform, v0, v1, v2, v3 float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform4f(%v, %v, %v, %v, %v) %v", dst, v0, v1, v2, v3, errstr)
	}()
	C.glUniform4f(dst.c(), C.GLfloat(v0), C.GLfloat(v1), C.GLfloat(v2), C.GLfloat(v3))
}

func Uniform4fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform4fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniform4fv(dst.c(), C.GLsizei(len(src)/4), (*C.GLfloat)(&src[0]))
}

func Uniform4i(dst Uniform, v0, v1, v2, v3 int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform4i(%v, %v, %v, %v, %v) %v", dst, v0, v1, v2, v3, errstr)
	}()
	C.glUniform4i(dst.c(), C.GLint(v0), C.GLint(v1), C.GLint(v2), C.GLint(v3))
}

func Uniform4iv(dst Uniform, src []int32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Uniform4iv(%v, %v) %v", dst, src, errstr)
	}()
	C.glUniform4iv(dst.c(), C.GLsizei(len(src)/4), (*C.GLint)(&src[0]))
}

func UniformMatrix2fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.UniformMatrix2fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniformMatrix2fv(dst.c(), C.GLsizei(len(src)/4), 0, (*C.GLfloat)(&src[0]))
}

func UniformMatrix3fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.UniformMatrix3fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniformMatrix3fv(dst.c(), C.GLsizei(len(src)/9), 0, (*C.GLfloat)(&src[0]))
}

func UniformMatrix4fv(dst Uniform, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.UniformMatrix4fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glUniformMatrix4fv(dst.c(), C.GLsizei(len(src)/16), 0, (*C.GLfloat)(&src[0]))
}

func UseProgram(p Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.UseProgram(%v) %v", p, errstr)
	}()
	C.glUseProgram(p.c())
}

func ValidateProgram(p Program) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.ValidateProgram(%v) %v", p, errstr)
	}()
	C.glValidateProgram(p.c())
}

func VertexAttrib1f(dst Attrib, x float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib1f(%v, %v) %v", dst, x, errstr)
	}()
	C.glVertexAttrib1f(dst.c(), C.GLfloat(x))
}

func VertexAttrib1fv(dst Attrib, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib1fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glVertexAttrib1fv(dst.c(), (*C.GLfloat)(&src[0]))
}

func VertexAttrib2f(dst Attrib, x, y float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib2f(%v, %v, %v) %v", dst, x, y, errstr)
	}()
	C.glVertexAttrib2f(dst.c(), C.GLfloat(x), C.GLfloat(y))
}

func VertexAttrib2fv(dst Attrib, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib2fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glVertexAttrib2fv(dst.c(), (*C.GLfloat)(&src[0]))
}

func VertexAttrib3f(dst Attrib, x, y, z float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib3f(%v, %v, %v, %v) %v", dst, x, y, z, errstr)
	}()
	C.glVertexAttrib3f(dst.c(), C.GLfloat(x), C.GLfloat(y), C.GLfloat(z))
}

func VertexAttrib3fv(dst Attrib, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib3fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glVertexAttrib3fv(dst.c(), (*C.GLfloat)(&src[0]))
}

func VertexAttrib4f(dst Attrib, x, y, z, w float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib4f(%v, %v, %v, %v, %v) %v", dst, x, y, z, w, errstr)
	}()
	C.glVertexAttrib4f(dst.c(), C.GLfloat(x), C.GLfloat(y), C.GLfloat(z), C.GLfloat(w))
}

func VertexAttrib4fv(dst Attrib, src []float32) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttrib4fv(%v, len(%d)) %v", dst, len(src), errstr)
	}()
	C.glVertexAttrib4fv(dst.c(), (*C.GLfloat)(&src[0]))
}

func VertexAttribPointer(dst Attrib, size int, ty Enum, normalized bool, stride, offset int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.VertexAttribPointer(%v, %v, %v, %v, %v, %v) %v", dst, size, ty, normalized, stride, offset, errstr)
	}()
	n := glBoolean(normalized)
	s := C.GLsizei(stride)
	C.glVertexAttribPointer(dst.c(), C.GLint(size), ty.c(), n, s, unsafe.Pointer(uintptr(offset)))
}

func Viewport(x, y, width, height int) {
	defer func() {
		errstr := errDrain()
		log.Printf("gl.Viewport(%v, %v, %v, %v) %v", x, y, width, height, errstr)
	}()
	C.glViewport(C.GLint(x), C.GLint(y), C.GLsizei(width), C.GLsizei(height))
}
