// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package portable implements a sprite Engine using the image package.
//
// It is intended to serve as a reference implementation for testing
// other sprite Engines written against OpenGL, or other more exotic
// modern hardware interfaces.
package portable // import "golang.org/x/mobile/sprite/portable"

import (
	"image"
	"image/draw"

	"golang.org/x/mobile/f32"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/sprite"
	"golang.org/x/mobile/sprite/clock"
)

// Engine builds a sprite Engine that renders onto dst.
func Engine(dst *image.RGBA) sprite.Engine {
	return &engine{
		dst:   dst,
		nodes: []*node{nil},
	}
}

type node struct {
	// TODO: move this into package sprite as Node.EngineFields.RelTransform??
	relTransform f32.Affine
}

type texture struct {
	m *image.RGBA
}

func (t *texture) Bounds() (w, h int) {
	b := t.m.Bounds()
	return b.Dx(), b.Dy()
}

func (t *texture) Download(r image.Rectangle, dst draw.Image) {
	draw.Draw(dst, r, t.m, t.m.Bounds().Min, draw.Src)
}

func (t *texture) Upload(r image.Rectangle, src image.Image) {
	draw.Draw(t.m, r, src, src.Bounds().Min, draw.Src)
}

func (t *texture) Unload() { panic("TODO") }

type engine struct {
	dst           *image.RGBA
	nodes         []*node
	absTransforms []f32.Affine
}

func (e *engine) Register(n *sprite.Node) {
	if n.EngineFields.Index != 0 {
		panic("portable: sprite.Node already registered")
	}

	o := &node{}
	o.relTransform.Identity()

	e.nodes = append(e.nodes, o)
	n.EngineFields.Index = int32(len(e.nodes) - 1)
}

func (e *engine) Unregister(n *sprite.Node) {
	panic("todo")
}

func (e *engine) LoadTexture(m image.Image) (sprite.Texture, error) {
	b := m.Bounds()
	w, h := b.Dx(), b.Dy()

	t := &texture{m: image.NewRGBA(image.Rect(0, 0, w, h))}
	t.Upload(b, m)
	return t, nil
}

func (e *engine) SetSubTex(n *sprite.Node, x sprite.SubTex) {
	n.EngineFields.Dirty = true // TODO: do we need to propagate dirtiness up/down the tree?
	n.EngineFields.SubTex = x
}

func (e *engine) SetTransform(n *sprite.Node, m f32.Affine) {
	n.EngineFields.Dirty = true // TODO: do we need to propagate dirtiness up/down the tree?
	e.nodes[n.EngineFields.Index].relTransform = m
}

func (e *engine) Render(scene *sprite.Node, t clock.Time) {
	// Affine transforms are done in geom.Pt. When finally drawing
	// the geom.Pt onto an image.Image we need to convert to system
	// pixels. We scale by geom.PixelsPerPt to do this.
	e.absTransforms = append(e.absTransforms[:0], f32.Affine{
		{geom.PixelsPerPt, 0, 0},
		{0, geom.PixelsPerPt, 0},
	})
	e.render(scene, t)
}

func (e *engine) render(n *sprite.Node, t clock.Time) {
	if n.EngineFields.Index == 0 {
		panic("portable: sprite.Node not registered")
	}
	if n.Arranger != nil {
		n.Arranger.Arrange(e, n, t)
	}

	// Push absTransforms.
	// TODO: cache absolute transforms and use EngineFields.Dirty?
	rel := &e.nodes[n.EngineFields.Index].relTransform
	m := f32.Affine{}
	m.Mul(&e.absTransforms[len(e.absTransforms)-1], rel)
	e.absTransforms = append(e.absTransforms, m)

	if x := n.EngineFields.SubTex; x.T != nil {
		// Affine transforms work in geom.Pt, which is entirely
		// independent of the number of pixels in a texture. A texture
		// of any image.Rectangle bounds rendered with
		//
		//	Affine{{1, 0, 0}, {0, 1, 0}}
		//
		// should have the dimensions (1pt, 1pt). To do this we divide
		// by the pixel width and height, reducing the texture to
		// (1px, 1px) of the destination image. Multiplying by
		// geom.PixelsPerPt, done in Render above, makes it (1pt, 1pt).
		dx, dy := x.R.Dx(), x.R.Dy()
		if dx > 0 && dy > 0 {
			m.Scale(&m, 1/float32(dx), 1/float32(dy))
			m.Inverse(&m) // See the documentation on the affine function.
			affine(e.dst, x.T.(*texture).m, x.R, nil, &m, draw.Over)
		}
	}

	for c := n.FirstChild; c != nil; c = c.NextSibling {
		e.render(c, t)
	}

	// Pop absTransforms.
	e.absTransforms = e.absTransforms[:len(e.absTransforms)-1]
}
