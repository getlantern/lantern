// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin

package glutil

import (
	"encoding/binary"
	"fmt"
	"image"
	"runtime"
	"sync"

	"golang.org/x/mobile/app"
	"golang.org/x/mobile/event/config"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/exp/f32"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
)

var glimage struct {
	quadXY        gl.Buffer
	quadUV        gl.Buffer
	program       gl.Program
	pos           gl.Attrib
	mvp           gl.Uniform
	uvp           gl.Uniform
	inUV          gl.Attrib
	textureSample gl.Uniform
}

func init() {
	app.RegisterFilter(func(e interface{}) interface{} {
		if e, ok := e.(lifecycle.Event); ok {
			switch e.Crosses(lifecycle.StageVisible) {
			case lifecycle.CrossOn:
				start()
			case lifecycle.CrossOff:
				stop()
			}
		}
		return e
	})
}

func start() {
	var err error
	glimage.program, err = CreateProgram(vertexShader, fragmentShader)
	if err != nil {
		panic(err)
	}

	glimage.quadXY = gl.CreateBuffer()
	glimage.quadUV = gl.CreateBuffer()

	gl.BindBuffer(gl.ARRAY_BUFFER, glimage.quadXY)
	gl.BufferData(gl.ARRAY_BUFFER, quadXYCoords, gl.STATIC_DRAW)
	gl.BindBuffer(gl.ARRAY_BUFFER, glimage.quadUV)
	gl.BufferData(gl.ARRAY_BUFFER, quadUVCoords, gl.STATIC_DRAW)

	glimage.pos = gl.GetAttribLocation(glimage.program, "pos")
	glimage.mvp = gl.GetUniformLocation(glimage.program, "mvp")
	glimage.uvp = gl.GetUniformLocation(glimage.program, "uvp")
	glimage.inUV = gl.GetAttribLocation(glimage.program, "inUV")
	glimage.textureSample = gl.GetUniformLocation(glimage.program, "textureSample")

	texmap.Lock()
	defer texmap.Unlock()
	for key, tex := range texmap.texs {
		texmap.init(key)
		tex.needsUpload = true
	}
}

func stop() {
	gl.DeleteProgram(glimage.program)
	gl.DeleteBuffer(glimage.quadXY)
	gl.DeleteBuffer(glimage.quadUV)

	texmap.Lock()
	for _, t := range texmap.texs {
		if t.gltex.Value != 0 {
			gl.DeleteTexture(t.gltex)
		}
		t.gltex = gl.Texture{}
	}
	texmap.Unlock()
}

type texture struct {
	gltex       gl.Texture
	width       int
	height      int
	needsUpload bool
}

var texmap = &texmapCache{
	texs: make(map[texmapKey]*texture),
	next: 1, // avoid using 0 to aid debugging
}

type texmapKey int

type texmapCache struct {
	sync.Mutex
	texs map[texmapKey]*texture
	next texmapKey

	// TODO(crawshaw): This is a workaround for having nowhere better to clean up deleted textures.
	// Better: app.UI(func() { gl.DeleteTexture(t) } in texmap.delete
	// Best: Redesign the gl package to do away with this painful notion of a UI thread.
	toDelete []gl.Texture
}

func (tm *texmapCache) create(dx, dy int) *texmapKey {
	tm.Lock()
	defer tm.Unlock()
	key := tm.next
	tm.next++
	tm.texs[key] = &texture{
		width:  dx,
		height: dy,
	}
	tm.init(key)
	return &key
}

// init creates an underlying GL texture for a key.
// Must be called with a valid GL context.
// Must hold tm.Mutex before calling.
func (tm *texmapCache) init(key texmapKey) {
	tex := tm.texs[key]
	if tex.gltex.Value != 0 {
		panic(fmt.Sprintf("attempting to init key (%v) with valid texture", key))
	}
	tex.gltex = gl.CreateTexture()

	gl.BindTexture(gl.TEXTURE_2D, tex.gltex)
	gl.TexImage2D(gl.TEXTURE_2D, 0, tex.width, tex.height, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

	for _, t := range tm.toDelete {
		gl.DeleteTexture(t)
	}
	tm.toDelete = nil
}

func (tm *texmapCache) delete(key texmapKey) {
	tm.Lock()
	defer tm.Unlock()
	tex := tm.texs[key]
	delete(tm.texs, key)
	if tex == nil {
		return
	}
	tm.toDelete = append(tm.toDelete, tex.gltex)
}

func (tm *texmapCache) get(key texmapKey) *texture {
	tm.Lock()
	defer tm.Unlock()
	return tm.texs[key]
}

// Image bridges between an *image.RGBA and an OpenGL texture.
//
// The contents of the embedded *image.RGBA can be uploaded as a
// texture and drawn as a 2D quad.
//
// The number of active Images must fit in the system's OpenGL texture
// limit. The typical use of an Image is as a texture atlas.
type Image struct {
	*image.RGBA
	key *texmapKey
}

// NewImage creates an Image of the given size.
//
// Both a host-memory *image.RGBA and a GL texture are created.
func NewImage(w, h int) *Image {
	dx := roundToPower2(w)
	dy := roundToPower2(h)

	// TODO(crawshaw): Using VertexAttribPointer we can pass texture
	// data with a stride, which would let us use the exact number of
	// pixels on the host instead of the rounded up power 2 size.
	m := image.NewRGBA(image.Rect(0, 0, dx, dy))

	img := &Image{
		RGBA: m.SubImage(image.Rect(0, 0, w, h)).(*image.RGBA),
		key:  texmap.create(dx, dy),
	}
	runtime.SetFinalizer(img.key, func(key *texmapKey) {
		texmap.delete(*key)
	})
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
	tex := texmap.get(*img.key)
	gl.BindTexture(gl.TEXTURE_2D, tex.gltex)
	gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, tex.width, tex.height, gl.RGBA, gl.UNSIGNED_BYTE, img.Pix)
}

// Delete invalidates the Image and removes any underlying data structures.
// The Image cannot be used after being deleted.
func (img *Image) Delete() {
	texmap.delete(*img.key)
}

// Draw draws the srcBounds part of the image onto a parallelogram, defined by
// three of its corners, in the current GL framebuffer.
func (img *Image) Draw(c config.Event, topLeft, topRight, bottomLeft geom.Point, srcBounds image.Rectangle) {
	// TODO(crawshaw): Adjust viewport for the top bar on android?
	gl.UseProgram(glimage.program)
	tex := texmap.get(*img.key)
	if tex.needsUpload {
		img.Upload()
		tex.needsUpload = false
	}

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
		px2 := -0.5 + float32(topLeft.X/c.Width)
		py2 := +0.5 - float32(topLeft.Y/c.Height)
		qx2 := -0.5 + float32(topRight.X/c.Width)
		qy2 := +0.5 - float32(topRight.Y/c.Height)
		sx2 := -0.5 + float32(bottomLeft.X/c.Width)
		sy2 := +0.5 - float32(bottomLeft.Y/c.Height)
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
		writeAffine(glimage.mvp, &f32.Affine{{
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
		w := float32(tex.width)
		h := float32(tex.height)
		px := float32(srcBounds.Min.X-img.Rect.Min.X) / w
		py := float32(srcBounds.Min.Y-img.Rect.Min.Y) / h
		qx := float32(srcBounds.Max.X-img.Rect.Min.X) / w
		sy := float32(srcBounds.Max.Y-img.Rect.Min.Y) / h
		// Due to axis alignment, qy = py and sx = px.
		//
		// The simultaneous equations are:
		//	  0 +   0 + a02 = px
		//	  0 +   0 + a12 = py
		//	a00 +   0 + a02 = qx
		//	a10 +   0 + a12 = qy = py
		//	  0 + a01 + a02 = sx = px
		//	  0 + a11 + a12 = sy
		writeAffine(glimage.uvp, &f32.Affine{{
			qx - px,
			0,
			px,
		}, {
			0,
			sy - py,
			py,
		}})
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, tex.gltex)
	gl.Uniform1i(glimage.textureSample, 0)

	gl.BindBuffer(gl.ARRAY_BUFFER, glimage.quadXY)
	gl.EnableVertexAttribArray(glimage.pos)
	gl.VertexAttribPointer(glimage.pos, 2, gl.FLOAT, false, 0, 0)

	gl.BindBuffer(gl.ARRAY_BUFFER, glimage.quadUV)
	gl.EnableVertexAttribArray(glimage.inUV)
	gl.VertexAttribPointer(glimage.inUV, 2, gl.FLOAT, false, 0, 0)

	gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

	gl.DisableVertexAttribArray(glimage.pos)
	gl.DisableVertexAttribArray(glimage.inUV)
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
