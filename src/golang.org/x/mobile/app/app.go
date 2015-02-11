// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux darwin

package app

import (
	"io"

	"golang.org/x/mobile/event"
)

// Run starts the app.
//
// It must be called directly from the main function and will
// block until the app exits.
func Run(cb Callbacks) {
	run(cb)
}

// Callbacks is the set of functions called by the app.
type Callbacks struct {
	// Start is called when the app enters the foreground.
	// The app will start receiving Draw and Touch calls.
	//
	// Window geometry will be configured and an OpenGL context
	// will be available.
	//
	// Start is an equivalent lifecycle state to onStart() on
	// Android and applicationDidBecomeActive on iOS.
	Start func()

	// Stop is called shortly before a program is suspended.
	//
	// When Stop is received, the app is no longer visible and not is
	// receiving events. It should:
	//
	//	- Save any state the user expects saved (for example text).
	//	- Release all resources that are not needed.
	//
	// Execution time in the stop state is limited, and the limit is
	// enforced by the operating system. Stop as quickly as you can.
	//
	// An app that is stopped may be started again. For example, the user
	// opens Recent Apps and switches to your app. A stopped app may also
	// be terminated by the operating system with no further warning.
	//
	// Stop is equivalent to onStop() on Android and
	// applicationDidEnterBackground on iOS.
	Stop func()

	// Draw is called by the render loop to draw the screen.
	//
	// Drawing is done into a framebuffer, which is then swapped onto the
	// screen when Draw returns. It is called 60 times a second.
	Draw func()

	// Touch is called by the app when a touch event occurs.
	Touch func(event.Touch)
}

// Open opens a named asset.
//
// On Android, assets are accessed via android.content.res.AssetManager.
// These files are stored in the assets/ directory of the app. Any raw asset
// can be accessed by its direct relative name. For example assets/img.png
// can be opened with Open("img.png").
//
// On iOS an asset is a resource stored in the application bundle.
// Resources can be loaded using the same relative paths.
//
// For consistency when debugging on a desktop, assets are read from a
// directoy named assets under the current working directory.
func Open(name string) (ReadSeekCloser, error) {
	return openAsset(name)
}

// ReadSeekCloser is an io.ReadSeeker and io.Closer.
type ReadSeekCloser interface {
	io.ReadSeeker
	io.Closer
}
