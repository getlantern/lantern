// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

package al

import (
	"errors"
	"sync"
	"unsafe"
)

var (
	mu sync.Mutex // mu protects Device and context

	// device is the currently open audio device or nil.
	device  unsafe.Pointer
	context unsafe.Pointer
)

// DeviceError returns the last known error from the current device.
func DeviceError() int32 {
	return alcGetError(device)
}

// TODO(jbd): Investigate the cases where multiple audio output
// devices might be needed.

// OpenDevice opens the default audio device.
func OpenDevice() error {
	mu.Lock()
	defer mu.Unlock()

	// already opened
	if device != nil {
		return nil
	}

	ptr := alcOpenDevice("")
	if ptr == nil {
		return errors.New("al: cannot open the default audio device")
	}
	ctx := alcCreateContext(ptr, nil)
	if ctx == nil {
		alcCloseDevice(ptr)
		return errors.New("al: cannot create a new context")
	}
	alcMakeContextCurrent(ctx)
	device = ptr
	context = ctx
	return nil
}

// CloseDevice closes the device and frees related resources.
func CloseDevice() {
	mu.Lock()
	defer mu.Unlock()

	alcMakeContextCurrent(nil)

	if context != nil {
		alcDestroyContext(context)
		context = nil
	}

	if device != nil {
		alcCloseDevice(device)
		device = nil
	}
}
