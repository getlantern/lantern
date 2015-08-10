// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux,!android

package al

/*
#cgo darwin   CFLAGS:  -DGOOS_darwin
#cgo linux    CFLAGS:  -DGOOS_linux
#cgo darwin   LDFLAGS: -framework OpenAL
#cgo linux    LDFLAGS: -lopenal

#ifdef GOOS_darwin
#include <stdlib.h>
#include <OpenAL/alc.h>
#endif

#ifdef GOOS_linux
#include <stdlib.h>
#include <AL/alc.h>
#endif
*/
import "C"
import "unsafe"

/*
On Ubuntu 14.04 'Trusty', you may have to install these libraries:
sudo apt-get install libopenal-dev
*/

func alcGetError(d unsafe.Pointer) int32 {
	dev := (*C.ALCdevice)(d)
	return int32(C.alcGetError(dev))
}

func alcOpenDevice(name string) unsafe.Pointer {
	n := C.CString(name)
	defer C.free(unsafe.Pointer(n))

	return (unsafe.Pointer)(C.alcOpenDevice((*C.ALCchar)(unsafe.Pointer(n))))
}

func alcCloseDevice(d unsafe.Pointer) bool {
	dev := (*C.ALCdevice)(d)
	return C.alcCloseDevice(dev) == C.ALC_TRUE
}

func alcCreateContext(d unsafe.Pointer, attrs []int32) unsafe.Pointer {
	dev := (*C.ALCdevice)(d)
	return (unsafe.Pointer)(C.alcCreateContext(dev, nil))
}

func alcMakeContextCurrent(c unsafe.Pointer) bool {
	ctx := (*C.ALCcontext)(c)
	return C.alcMakeContextCurrent(ctx) == C.ALC_TRUE
}

func alcDestroyContext(c unsafe.Pointer) {
	C.alcDestroyContext((*C.ALCcontext)(c))
}
