// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package event defines user input events.
package event // import "golang.org/x/mobile/event"

/*
The best source on android input events is the NDK: include/android/input.h

iOS event handling guide:
https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS
*/

import (
	"fmt"

	"golang.org/x/mobile/geom"
)

// Touch is a user touch event.
//
// On Android, this is an AInputEvent with AINPUT_EVENT_TYPE_MOTION.
// On iOS, it is the UIEvent delivered to a UIView.
type Touch struct {
	Type TouchType
	Loc  geom.Point
}

func (t Touch) String() string {
	var ty string
	switch t.Type {
	case TouchStart:
		ty = "start"
	case TouchMove:
		ty = "move "
	case TouchEnd:
		ty = "end  "
	}
	return fmt.Sprintf("Touch{ %s, %s }", ty, t.Loc)
}

// TouchType describes the type of a touch event.
type TouchType byte

const (
	// TouchStart is a user first touching the device.
	//
	// On Android, this is a AMOTION_EVENT_ACTION_DOWN.
	// On iOS, this is a call to touchesBegan.
	TouchStart TouchType = iota

	// TouchMove is a user dragging across the device.
	//
	// A TouchMove is delivered between a TouchStart and TouchEnd.
	//
	// On Android, this is a AMOTION_EVENT_ACTION_MOVE.
	// On iOS, this is a call to touchesMoved.
	TouchMove

	// TouchEnd is a user no longer touching the device.
	//
	// On Android, this is a AMOTION_EVENT_ACTION_UP.
	// On iOS, this is a call to touchesEnded.
	TouchEnd
)
