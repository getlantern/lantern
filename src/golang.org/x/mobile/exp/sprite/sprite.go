// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package sprite provides a 2D scene graph for rendering and animation.
//
// A tree of nodes is drawn by a rendering Engine, provided by another
// package. The OS-independent Go version based on the image package is:
//
//	golang.org/x/mobile/exp/sprite/portable
//
// An Engine draws a screen starting at a root Node. The tree is walked
// depth-first, with affine transformations applied at each level.
//
// Nodes are rendered relative to their parent.
//
// Typical main loop:
//
//	for each frame {
//		quantize time.Now() to a clock.Time
//		process UI events
//		modify the scene's nodes and animations (Arranger values)
//		e.Render(scene, t, sz)
//	}
package sprite // import "golang.org/x/mobile/exp/sprite"

import (
	"image"
	"image/draw"

	"golang.org/x/mobile/event/size"
	"golang.org/x/mobile/exp/f32"
	"golang.org/x/mobile/exp/sprite/clock"
)

type Arranger interface {
	Arrange(e Engine, n *Node, t clock.Time)
}

type Texture interface {
	Bounds() (w, h int)
	Download(r image.Rectangle, dst draw.Image)
	Upload(r image.Rectangle, src image.Image)
	Release()
}

type SubTex struct {
	T Texture
	R image.Rectangle
}

type Engine interface {
	Register(n *Node)
	Unregister(n *Node)

	LoadTexture(a image.Image) (Texture, error)

	SetSubTex(n *Node, x SubTex)
	SetTransform(n *Node, m f32.Affine) // sets transform relative to parent.

	// Render renders the scene arranged at the given time, for the given
	// window configuration (dimensions and resolution).
	Render(scene *Node, t clock.Time, sz size.Event)

	Release()
}

// A Node is a renderable element and forms a tree of Nodes.
type Node struct {
	Parent, FirstChild, LastChild, PrevSibling, NextSibling *Node

	Arranger Arranger

	// EngineFields contains fields that should only be accessed by Engine
	// implementations. It is exported because such implementations can be
	// in other packages.
	EngineFields struct {
		// TODO: separate TexDirty and TransformDirty bits?
		Dirty  bool
		Index  int32
		SubTex SubTex
	}
}

// AppendChild adds a node c as a child of n.
//
// It will panic if c already has a parent or siblings.
func (n *Node) AppendChild(c *Node) {
	if c.Parent != nil || c.PrevSibling != nil || c.NextSibling != nil {
		panic("sprite: AppendChild called for an attached child Node")
	}
	last := n.LastChild
	if last != nil {
		last.NextSibling = c
	} else {
		n.FirstChild = c
	}
	n.LastChild = c
	c.Parent = n
	c.PrevSibling = last
}

// RemoveChild removes a node c that is a child of n. Afterwards, c will have
// no parent and no siblings.
//
// It will panic if c's parent is not n.
func (n *Node) RemoveChild(c *Node) {
	if c.Parent != n {
		panic("sprite: RemoveChild called for a non-child Node")
	}
	if n.FirstChild == c {
		n.FirstChild = c.NextSibling
	}
	if c.NextSibling != nil {
		c.NextSibling.PrevSibling = c.PrevSibling
	}
	if n.LastChild == c {
		n.LastChild = c.PrevSibling
	}
	if c.PrevSibling != nil {
		c.PrevSibling.NextSibling = c.NextSibling
	}
	c.Parent = nil
	c.PrevSibling = nil
	c.NextSibling = nil
}
