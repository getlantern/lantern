// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux windows

// An app that paints green if golang.org is reachable when the app first
// starts, or red otherwise.
//
// In order to access the network from the Android app, its AndroidManifest.xml
// file must include the permission to access the network.
//
//   http://developer.android.com/guide/topics/manifest/manifest-intro.html#perms
//
// The gomobile tool auto-generates a default AndroidManifest file by default
// unless the package directory contains the AndroidManifest.xml. Users can
// customize app behavior, such as permissions and app name, by providing
// the AndroidManifest file. This is irrelevent to iOS.
//
// Note: This demo is an early preview of Go 1.5. In order to build this
// program as an Android APK using the gomobile tool.
//
// See http://godoc.org/golang.org/x/mobile/cmd/gomobile to install gomobile.
//
// Get the network example and use gomobile to build or install it on your device.
//
//   $ go get -d golang.org/x/mobile/example/network
//   $ gomobile build golang.org/x/mobile/example/network # will build an APK
//
//   # plug your Android device to your computer or start an Android emulator.
//   # if you have adb installed on your machine, use gomobile install to
//   # build and deploy the APK to an Android target.
//   $ gomobile install golang.org/x/mobile/example/network
//
// Switch to your device or emulator to start the network application from
// the launcher.
// You can also run the application on your desktop by running the command
// below. (Note: It currently doesn't work on Windows.)
//   $ go install golang.org/x/mobile/example/network && network
package main

import (
	"net/http"

	"golang.org/x/mobile/app"
	"golang.org/x/mobile/event/lifecycle"
	"golang.org/x/mobile/event/paint"
	"golang.org/x/mobile/event/size"
	"golang.org/x/mobile/gl"
)

func main() {
	// checkNetwork runs only once when the app first loads.
	go checkNetwork()

	app.Main(func(a app.App) {
		var glctx gl.Context
		det, sz := determined, size.Event{}
		for {
			select {
			case <-det:
				a.Send(paint.Event{})
				det = nil

			case e := <-a.Events():
				switch e := a.Filter(e).(type) {
				case lifecycle.Event:
					glctx, _ = e.DrawContext.(gl.Context)
				case size.Event:
					sz = e
				case paint.Event:
					if glctx == nil {
						continue
					}
					onDraw(glctx, sz)
					a.Publish()
				}
			}
		}
	})
}

var (
	determined = make(chan struct{})
	ok         = false
)

func checkNetwork() {
	defer close(determined)

	_, err := http.Get("http://golang.org/")
	if err != nil {
		return
	}
	ok = true
}

func onDraw(glctx gl.Context, sz size.Event) {
	select {
	case <-determined:
		if ok {
			glctx.ClearColor(0, 1, 0, 1)
		} else {
			glctx.ClearColor(1, 0, 0, 1)
		}
	default:
		glctx.ClearColor(0, 0, 0, 1)
	}
	glctx.Clear(gl.COLOR_BUFFER_BIT)
}
