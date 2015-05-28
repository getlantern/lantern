// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package glsprite implements a sprite Engine using OpenGL ES 2.
//
// Each sprite.Texture is loaded as a GL texture object and drawn
// to the screen via an affine transform done in a simple shader.
package glsprite // import "golang.org/x/mobile/sprite/glsprite"

import (
	"image"
	"image/draw"

	"golang.org/x/mobile/f32"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl/glutil"
	"golang.org/x/mobile/sprite"
	"golang.org/x/mobile/sprite/clock"
)

type node struct {
	// TODO: move this into package sprite as Node.EngineFields.RelTransform??
	relTransform f32.Affine
}

type texture struct {
	glImage *glutil.Image
	b       image.Rectangle
}

func (t *texture) Bounds() (w, h int) { return t.b.Dx(), t.b.Dy() }

func (t *texture) Download(r image.Rectangle, dst draw.Image) {
	panic("TODO")
}

func (t *texture) Upload(r image.Rectangle, src image.Image) {
	draw.Draw(t.glImage.RGBA, r, src, src.Bounds().Min, draw.Src)
	t.glImage.Upload()
}

func (t *texture) Unload() {
	panic("TODO")
}

func Engine() sprite.Engine {
	return &engine{
		nodes: []*node{nil},
	}
}

type engine struct {
	glImages map[sprite.Texture]*glutil.Image
	nodes    []*node

	absTransforms []f32.Affine
}

func (e *engine) Register(n *sprite.Node) {
	if n.EngineFields.Index != 0 {
		panic("glsprite: sprite.Node already registered")
	}
	o := &node{}
	o.relTransform.Identity()

	e.nodes = append(e.nodes, o)
	n.EngineFields.Index = int32(len(e.nodes) - 1)
}

func (e *engine) Unregister(n *sprite.Node) {
	panic("todo")
}

func (e *engine) LoadTexture(src image.Image) (sprite.Texture, error) {
	b := src.Bounds()
	t := &texture{glutil.NewImage(b.Dx(), b.Dy()), b}
	t.Upload(b, src)
	// TODO: set "glImage.Pix = nil"?? We don't need the CPU-side image any more.
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
	e.absTransforms = append(e.absTransforms[:0], f32.Affine{
		{1, 0, 0},
		{0, 1, 0},
	})
	e.render(scene, t)
}

func (e *engine) render(n *sprite.Node, t clock.Time) {
	if n.EngineFields.Index == 0 {
		panic("glsprite: sprite.Node not registered")
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
		x.T.(*texture).glImage.Draw(
			geom.Point{
				geom.Pt(m[0][2]),
				geom.Pt(m[1][2]),
			},
			geom.Point{
				geom.Pt(m[0][2] + m[0][0]),
				geom.Pt(m[1][2] + m[1][0]),
			},
			geom.Point{
				geom.Pt(m[0][2] + m[0][1]),
				geom.Pt(m[1][2] + m[1][1]),
			},
			x.R,
		)
	}

	for c := n.FirstChild; c != nil; c = c.NextSibling {
		e.render(c, t)
	}

	// Pop absTransforms.
	e.absTransforms = e.absTransforms[:len(e.absTransforms)-1]
}
