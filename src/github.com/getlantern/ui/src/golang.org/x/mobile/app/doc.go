// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
Package app lets you write Apps for Android (and eventually, iOS).

There are two ways to use Go in an Android App. The first is as a
library called from Java, the second is to use a restricted set of
features but work entirely in Go.

Shared Library

A Go program can be compiled for Android as a shared library. JNI
methods can be implemented via cgo, or generated automatically with
gobind: http://golang.org/x/mobile/cmd/gobind

The library must include a package main and a main function that does
not return until the process exits. Libraries can be cross-compiled
using the Android NDK and the Go tool:

	GOOS=android GOARCH=arm GOARM=7 CGO_ENABLED=1 \
	go build -ldflags="-shared" .

See http://golang.org/x/mobile/example/libhello for an example of
calling into a Go shared library from a Java Android app.

Native App

An app can be written entirely in Go. This results in a significantly
simpler programming environment (and eventually, portability to iOS),
however only a very restricted set of Android APIs are available.

The provided interfaces are focused on games. It is expected that the
app will draw to the entire screen (via OpenGL, see the go.mobile/gl
package), and that none of the platform's screen management
infrastructure is exposed. On Android, this means a native app is
equivalent to a single Activity (in particular a NativeActivity) and
on iOS, a single UIWindow. Touch events will be accessible via this
package. When Android support is out of preview, all APIs supported by
the Android NDK will be exposed via a Go package.

See http://golang.org/x/mobile/example/sprite for an example app.

Lifecycle in Native Apps

App execution begins in platform-specific code. Early on in the app's
life, the Go runtime is initialized and the Go main function is called.
(For Android, this is in ANativeActivity_onCreate, for iOS,
application:willFinishLaunchingWithOptions.)

An app is expected to call the Run function in its main. When the main
function exits, the app exits.

	package main

	import (
		"log"

		"golang.org/x/mobile/app"
	)

	func main() {
		app.Run(app.Callbacks{
			Draw: draw,
		})
	}

	func draw() {
		log.Print("In draw loop, can call OpenGL.")
	}

*/
package app // import "golang.org/x/mobile/app"
