// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package clock provides a clock and time functions for a sprite engine.
package clock // import "golang.org/x/mobile/exp/sprite/clock"

// A Time represents an instant in sprite time.
//
// The application using the sprite engine is responsible for
// determining sprite time.
//
// Typically time 0 is when the app is initialized and time is
// quantized at the intended frame rate. For example, an app may
// record wall time when it is initialized
//
//	var start = time.Now()
//
// and then compute the current instant in time for 60 FPS:
//
//	now := clock.Time(time.Since(start) * 60 / time.Second)
//
// An application can pause or reset sprite time, but it must be aware
// of any stateful sprite.Arranger instances that expect time to
// continue.
type Time int32
