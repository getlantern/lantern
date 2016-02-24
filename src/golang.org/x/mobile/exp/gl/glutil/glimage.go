// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin windows

package glutil

import (
	"encoding/binary"
	"image"
	"runtime"
	"sync"

	"golang.org/x/mobile/event/size"
	"golang.org/x/mobile/exp/f32"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

// Images maintains the shared state used by a set of *Image objects.
type Images struct {
	glctx         gl.Context
	quadXY        gl.Buffer
	quadUV        gl.Buffer
	program       gl.Program
	pos           gl.Attrib
	mvp           gl.Uniform
	uvp           gl.Uniform
	inUV          gl.Attrib
	textureSample gl.Uniform

	mu           sync.Mutex
	activeImages int
}

// NewImages creates an *Images.
func NewImages(glctx gl.Context) *Images {
	program, err := CreateProgram(glctx, vertexShader, fragmentShader)
	if err != nil {
		panic(err)
	}

	p := &Images{
		glctx:         glctx,
		quadXY:        glctx.CreateBuffer(),
		quadUV:        glctx.CreateBuffer(),
		program:       program,
		pos:           glctx.GetAttribLocation(program, "pos"),
		mvp:           glctx.GetUniformLocation(program, "mvp"),
		uvp:           glctx.GetUniformLocation(program, "uvp"),
		inUV:          glctx.GetAttribLocation(program, "inUV"),
		textureSample: glctx.GetUniformLocation(program, "textureSample"),
	}

	glctx.BindBuffer(gl.ARRAY_BUFFER, p.quadXY)
	glctx.BufferData(gl.ARRAY_BUFFER, quadXYCoords, gl.STATIC_DRAW)
	glctx.BindBuffer(gl.ARRAY_BUFFER, p.quadUV)
	glctx.BufferData(gl.ARRAY_BUFFER, quadUVCoords, gl.STATIC_DRAW)

	return p
}

// Release releases any held OpenGL resources.
// All *Image objects must be released first, or this function panics.
func (p *Images) Release() {
	if p.program == (gl.Program{}) {
		return
	}

	p.mu.Lock()
	rem := p.activeImages
	p.mu.Unlock()
	if rem > 0 {
		panic("glutil.Images.Release called, but active *Image objects remain")
	}

	p.glctx.DeleteProgram(p.program)
	p.glctx.DeleteBuffer(p.quadXY)
	p.glctx.DeleteBuffer(p.quadUV)

	p.program = gl.Program{}
}

// Image bridges between an *image.RGBA and an OpenGL texture.
//
// The contents of the *image.RGBA can be uploaded as a texture and drawn as a
// 2D quad.
//
// The number of active Images must fit in the system's OpenGL texture limit.
// The typical use of an Image is as a texture atlas.
type Image struct {
	RGBA *image.RGBA

	gltex  gl.Texture
	width  int
	height int
	images *Images
}

// NewImage creates an Image of the given size.
//
// Both a host-memory *image.RGBA and a GL texture are created.
func (p *Images) NewImage(w, h int) *Image {
	dx := roundToPower2(w)
	dy := roundToPower2(h)

	// TODO(crawshaw): Using VertexAttribPointer we can pass texture
	// data with a stride, which would let us use the exact number of
	// pixels on the host instead of the rounded up power 2 size.
	m := image.NewRGBA(image.Rect(0, 0, dx, dy))

	img := &Image{
		RGBA:   m.SubImage(image.Rect(0, 0, w, h)).(*image.RGBA),
		images: p,
		width:  dx,
		height: dy,
	}

	p.mu.Lock()
	p.activeImages++
	p.mu.Unlock()

	img.gltex = p.glctx.CreateTexture()

	p.glctx.BindTexture(gl.TEXTURE_2D, img.gltex)
	p.glctx.TexImage2D(gl.TEXTURE_2D, 0, img.width, img.height, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	p.glctx.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	p.glctx.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	p.glctx.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	p.glctx.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	runtime.SetFinalizer(img, (*Image).Release)
	return img
}

func roundToPower2(x int) int {
	x2 := 1
	for x2 < x {
		x2 *= 2
	}
	return x2
}

// Upload copies the host image data to the GL device.
func (img *Image) Upload() {
	img.images.glctx.BindTexture(gl.TEXTURE_2D, img.gltex)
	img.images.glctx.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, img.width, img.height, gl.RGBA, gl.UNSIGNED_BYTE, img.RGBA.Pix)
}

// Release invalidates the Image and removes any underlying data structures.
// The Image cannot be used after being deleted.
func (img *Image) Release() {
	if img.gltex == (gl.Texture{}) {
		return
	}

	img.images.glctx.DeleteTexture(img.gltex)
	img.gltex = gl.Texture{}

	img.images.mu.Lock()
	img.images.activeImages--
	img.images.mu.Unlock()
}

// Draw draws the srcBounds part of the image onto a parallelogram, defined by
// three of its corners, in the current GL framebuffer.
func (img *Image) Draw(sz size.Event, topLeft, topRight, bottomLeft geom.Point, srcBounds image.Rectangle) {
	glimage := img.images
	glctx := img.images.glctx

	glctx.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
	glctx.Enable(gl.BLEND)

	// TODO(crawshaw): Adjust viewport for the top bar on android?
	glctx.UseProgram(glimage.program)
	{
		// We are drawing a parallelogram PQRS, defined by three of its
		// corners, onto the entire GL framebuffer ABCD. The two quads may
		// actually be equal, but in the general case, PQRS can be smaller,
		// and PQRS is not necessarily axis-aligned.
		//
		//	A +---------------+ B
		//	  |  P +-----+ Q  |
		//	  |    |     |    |
		//	  |  S +-----+ R  |
		//	D +---------------+ C
		//
		// There are two co-ordinate spaces: geom space and framebuffer space.
		// In geom space, the ABCD rectangle is:
		//
		//	(0, 0)           (geom.Width, 0)
		//	(0, geom.Height) (geom.Width, geom.Height)
		//
		// and the PQRS quad is:
		//
		//	(topLeft.X,    topLeft.Y)    (topRight.X, topRight.Y)
		//	(bottomLeft.X, bottomLeft.Y) (implicit,   implicit)
		//
		// In framebuffer space, the ABCD rectangle is:
		//
		//	(-1, +1) (+1, +1)
		//	(-1, -1) (+1, -1)
		//
		// First of all, convert from geom space to framebuffer space. For
		// later convenience, we divide everything by 2 here: px2 is half of
		// the P.X co-ordinate (in framebuffer space).
		px2 := -0.5 + float32(topLeft.X/sz.WidthPt)
		py2 := +0.5 - float32(topLeft.Y/sz.HeightPt)
		qx2 := -0.5 + float32(topRight.X/sz.WidthPt)
		qy2 := +0.5 - float32(topRight.Y/sz.HeightPt)
		sx2 := -0.5 + float32(bottomLeft.X/sz.WidthPt)
		sy2 := +0.5 - float32(bottomLeft.Y/sz.HeightPt)
		// Next, solve for the affine transformation matrix
		//	    [ a00 a01 a02 ]
		//	a = [ a10 a11 a12 ]
		//	    [   0   0   1 ]
		// that maps A to P:
		//	a × [ -1 +1 1 ]' = [ 2*px2 2*py2 1 ]'
		// and likewise maps B to Q and D to S. Solving those three constraints
		// implies that C maps to R, since affine transformations keep parallel
		// lines parallel. This gives 6 equations in 6 unknowns:
		//	-a00 + a01 + a02 = 2*px2
		//	-a10 + a11 + a12 = 2*py2
		//	+a00 + a01 + a02 = 2*qx2
		//	+a10 + a11 + a12 = 2*qy2
		//	-a00 - a01 + a02 = 2*sx2
		//	-a10 - a11 + a12 = 2*sy2
		// which gives:
		//	a00 = (2*qx2 - 2*px2) / 2 = qx2 - px2
		// and similarly for the other elements of a.
		writeAffine(glctx, glimage.mvp, &f32.Affine{{
			qx2 - px2,
			px2 - sx2,
			qx2 + sx2,
		}, {
			qy2 - py2,
			py2 - sy2,
			qy2 + sy2,
		}})
	}

	{
		// Mapping texture co-ordinates is similar, except that in texture
		// space, the ABCD rectangle is:
		//
		//	(0,0) (1,0)
		//	(0,1) (1,1)
		//
		// and the PQRS quad is always axis-aligned. First of all, convert
		// from pixel space to texture space.
		w := float32(img.width)
		h := float32(img.height)
		px := float32(srcBounds.Min.X-img.RGBA.Rect.Min.X) / w
		py := float32(srcBounds.Min.Y-img.RGBA.Rect.Min.Y) / h
		qx := float32(srcBounds.Max.X-img.RGBA.Rect.Min.X) / w
		sy := float32(srcBounds.Max.Y-img.RGBA.Rect.Min.Y) / h
		// Due to axis alignment, qy = py and sx = px.
		//
		// The simultaneous equations are:
		//	  0 +   0 + a02 = px
		//	  0 +   0 + a12 = py
		//	a00 +   0 + a02 = qx
		//	a10 +   0 + a12 = qy = py
		//	  0 + a01 + a02 = sx = px
		//	  0 + a11 + a12 = sy
		writeAffine(glctx, glimage.uvp, &f32.Affine{{
			qx - px,
			0,
			px,
		}, {
			0,
			sy - py,
			py,
		}})
	}

	glctx.ActiveTexture(gl.TEXTURE0)
	glctx.BindTexture(gl.TEXTURE_2D, img.gltex)
	glctx.Uniform1i(glimage.textureSample, 0)

	glctx.BindBuffer(gl.ARRAY_BUFFER, glimage.quadXY)
	glctx.EnableVertexAttribArray(glimage.pos)
	glctx.VertexAttribPointer(glimage.pos, 2, gl.FLOAT, false, 0, 0)

	glctx.BindBuffer(gl.ARRAY_BUFFER, glimage.quadUV)
	glctx.EnableVertexAttribArray(glimage.inUV)
	glctx.VertexAttribPointer(glimage.inUV, 2, gl.FLOAT, false, 0, 0)

	glctx.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	glctx.DisableVertexAttribArray(glimage.pos)
	glctx.DisableVertexAttribArray(glimage.inUV)

	glctx.Disable(gl.BLEND)
}

var quadXYCoords = f32.Bytes(binary.LittleEndian,
	-1, +1, // top left
	+1, +1, // top right
	-1, -1, // bottom left
	+1, -1, // bottom right
)

var quadUVCoords = f32.Bytes(binary.LittleEndian,
	0, 0, // top left
	1, 0, // top right
	0, 1, // bottom left
	1, 1, // bottom right
)

const vertexShader = `#version 100
uniform mat3 mvp;
uniform mat3 uvp;
attribute vec3 pos;
attribute vec2 inUV;
varying vec2 UV;
void main() {
	vec3 p = pos;
	p.z = 1.0;
	gl_Position = vec4(mvp * p, 1);
	UV = (uvp * vec3(inUV, 1)).xy;
}
`

const fragmentShader = `#version 100
precision mediump float;
varying vec2 UV;
uniform sampler2D textureSample;
void main(){
	gl_FragColor = texture2D(textureSample, UV);
}
`
