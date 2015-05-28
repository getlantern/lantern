// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package app

/*
There are three notions of state at work in this package.

The first is Unix process state. Because mobile devices can be compiled
as -buildmode=c-shared and -buildmode=c-archive, there is code in this
package executed by global constructor which runs before (and even is
reponsible for triggering) the Go main function call. This is tracked
by the mainCalled channel.

The second is runState. An app may "Start" and "Stop" multiple times
over the life of the unix process. This involes the creation and
destruction of OpenGL windows and calling user Callbacks. Some user
functions must block in the stop state.

The third is Config, user-visible app configuration. It is only
available after the app has started.
*/

import (
	"sync"

	"golang.org/x/mobile/geom"
)

// mainCalled is closed after the Go main and app.Run functions have
// been called. This happens before an app enters the start state and
// may happen before a window is created (on android).
var mainCalled = make(chan struct{})

var (
	configCurMu sync.Mutex // guards configCur pointer, not contents
	configCur   Config
	configAlt   Config // used to stage new state
)

func init() {
	// Configuration is not available while the app is stopped,
	// so we begin the program with configCurMu locked. It will
	// be locked whenever !running.
	configCurMu.Lock()
}

var (
	running    = false
	startFuncs []func()
	stopFuncs  []func()
)

func stateStart(callbacks []Callbacks) {
	if running {
		return
	}
	running = true
	configCurMu.Unlock() // GetConfig is now available
	for _, cb := range callbacks {
		if cb.Start != nil {
			cb.Start()
		}
	}
}

func stateStop(callbacks []Callbacks) {
	if !running {
		return
	}
	running = false
	configCurMu.Lock() // GetConfig is no longer available
	for _, cb := range callbacks {
		if cb.Stop != nil {
			cb.Stop()
		}
	}
}

// configSwap is called to replace configCur with configAlt and if
// necessary inform the running the app. Calls to configSwap must be
// made after updating configAlt.
func configSwap(callbacks []Callbacks) {
	if !running {
		// configCurMu is already locked, and no-one else
		// is around to look at configCur, so we modify it
		// directly.
		configCur = configAlt
		geom.Width, geom.Height = configCur.Width, configCur.Height // TODO: remove
		return
	}

	configCurMu.Lock()
	old := configCur
	configCur = configAlt
	configCurMu.Unlock()

	geom.Width, geom.Height = configCur.Width, configCur.Height // TODO: remove

	for _, cb := range callbacks {
		if cb.Config != nil {
			cb.Config(configCur, old)
		}
	}
}
