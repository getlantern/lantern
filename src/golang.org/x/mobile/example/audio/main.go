// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// An app that makes a sound as the gopher hits the walls of the screen.
//
// Note: This demo is an early preview of Go 1.5. In order to build this
// program as an Android APK using the gomobile tool.
//
// See http://godoc.org/golang.org/x/mobile/cmd/gomobile to install gomobile.
//
// Get the audio example and use gomobile to build or install it on your device.
//
//   $ go get -d golang.org/x/mobile/example/audio
//   $ gomobile build golang.org/x/mobile/example/audio # will build an APK
//
//   # plug your Android device to your computer or start an Android emulator.
//   # if you have adb installed on your machine, use gomobile install to
//   # build and deploy the APK to an Android target.
//   $ gomobile install golang.org/x/mobile/example/audio
//
// Additionally, you can run the sample on your desktop environment
// by using the go tool.
//
//   $ go install golang.org/x/mobile/example/audio && audio
//
// On Linux, you need to install OpenAL developer library by
// running the command below.
//
//   $ apt-get install libopenal-dev
package main

import (
	"image"
	"log"
	"time"

	_ "image/jpeg"

	"golang.org/x/mobile/app"
	"golang.org/x/mobile/app/debug"
	"golang.org/x/mobile/audio"
	"golang.org/x/mobile/f32"
	"golang.org/x/mobile/geom"
	"golang.org/x/mobile/gl"
	"golang.org/x/mobile/sprite"
	"golang.org/x/mobile/sprite/clock"
	"golang.org/x/mobile/sprite/glsprite"
)

const (
	width  = 72
	height = 60
)

var (
	startClock = time.Now()
	lastClock  = clock.Time(-1)

	eng   = glsprite.Engine()
	scene *sprite.Node

	player *audio.Player
)

func main() {
	app.Run(app.Callbacks{
		Start: start,
		Stop:  stop,
		Draw:  draw,
	})
}

func start() {
	rc, err := app.Open("boing.wav")
	if err != nil {
		log.Fatal(err)
	}
	player, err = audio.NewPlayer(rc, 0, 0)
	if err != nil {
		log.Fatal(err)
	}
}

func stop() {
	player.Close()
}

func draw() {
	if scene == nil {
		loadScene()
	}

	now := clock.Time(time.Since(startClock) * 60 / time.Second)
	if now == lastClock {
		// TODO: figure out how to limit draw callbacks to 60Hz instead of
		// burning the CPU as fast as possible.
		// TODO: (relatedly??) sync to vblank?
		return
	}
	lastClock = now

	gl.ClearColor(1, 1, 1, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	eng.Render(scene, now)
	debug.DrawFPS()
}

func newNode() *sprite.Node {
	n := &sprite.Node{}
	eng.Register(n)
	scene.AppendChild(n)
	return n
}

func loadScene() {
	gopher := loadGopher()
	scene = &sprite.Node{}
	eng.Register(scene)
	eng.SetTransform(scene, f32.Affine{
		{1, 0, 0},
		{0, 1, 0},
	})

	var x, y float32
	dx, dy := float32(1), float32(1)

	n := newNode()
	n.Arranger = arrangerFunc(func(eng sprite.Engine, n *sprite.Node, t clock.Time) {
		eng.SetSubTex(n, gopher)

		if x < 0 {
			dx = 1
			boing()
		}
		if y < 0 {
			dy = 1
			boing()
		}
		if x+width > float32(geom.Width) {
			dx = -1
			boing()
		}
		if y+height > float32(geom.Height) {
			dy = -1
			boing()
		}

		x += dx
		y += dy

		eng.SetTransform(n, f32.Affine{
			{width, 0, x},
			{0, height, y},
		})
	})
}

func boing() {
	// TODO(jbd): the sound explodes at seek, volume down and seek?
	player.Seek(0)
	player.Play()
}

func loadGopher() sprite.SubTex {
	a, err := app.Open("gopher.jpeg")
	if err != nil {
		log.Fatal(err)
	}
	defer a.Close()

	img, _, err := image.Decode(a)
	if err != nil {
		log.Fatal(err)
	}
	t, err := eng.LoadTexture(img)
	if err != nil {
		log.Fatal(err)
	}
	return sprite.SubTex{t, image.Rect(0, 0, 360, 300)}
}

type arrangerFunc func(e sprite.Engine, n *sprite.Node, t clock.Time)

func (a arrangerFunc) Arrange(e sprite.Engine, n *sprite.Node, t clock.Time) { a(e, n, t) }
