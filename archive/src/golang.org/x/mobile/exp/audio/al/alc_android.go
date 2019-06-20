// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package al

/*
#include <stdlib.h>
#include <dlfcn.h>
#include <AL/al.h>
#include <AL/alc.h>

ALCint call_alcGetError(LPALCGETERROR fn, ALCdevice* d) {
  return fn(d);
}

ALCdevice* call_alcOpenDevice(LPALCOPENDEVICE fn, const ALCchar* name) {
  return fn(name);
}

ALCboolean call_alcCloseDevice(LPALCCLOSEDEVICE fn, ALCdevice* d) {
  return fn(d);
}

ALCcontext* call_alcCreateContext(LPALCCREATECONTEXT fn, ALCdevice* d, const ALCint* attrs) {
  return fn(d, attrs);
}

ALCboolean call_alcMakeContextCurrent(LPALCMAKECONTEXTCURRENT fn, ALCcontext* c) {
  return fn(c);
}

void call_alcDestroyContext(LPALCDESTROYCONTEXT fn, ALCcontext* c) {
  return fn(c);
}
*/
import "C"
import (
	"sync"
	"unsafe"
)

var once sync.Once

func alcGetError(d unsafe.Pointer) int32 {
	dev := (*C.ALCdevice)(d)
	return int32(C.call_alcGetError(alcGetErrorFunc, dev))
}

func alcOpenDevice(name string) unsafe.Pointer {
	once.Do(initAL)
	n := C.CString(name)
	defer C.free(unsafe.Pointer(n))

	return (unsafe.Pointer)(C.call_alcOpenDevice(alcOpenDeviceFunc, (*C.ALCchar)(unsafe.Pointer(n))))
}

func alcCloseDevice(d unsafe.Pointer) bool {
	dev := (*C.ALCdevice)(d)
	return C.call_alcCloseDevice(alcCloseDeviceFunc, dev) == C.AL_TRUE
}

func alcCreateContext(d unsafe.Pointer, attrs []int32) unsafe.Pointer {
	dev := (*C.ALCdevice)(d)
	// TODO(jbd): Handle attrs.
	return (unsafe.Pointer)(C.call_alcCreateContext(alcCreateContextFunc, dev, nil))
}

func alcMakeContextCurrent(c unsafe.Pointer) bool {
	ctx := (*C.ALCcontext)(c)
	return C.call_alcMakeContextCurrent(alcMakeContextCurrentFunc, ctx) == C.AL_TRUE
}

func alcDestroyContext(c unsafe.Pointer) {
	C.call_alcDestroyContext(alcDestroyContextFunc, (*C.ALCcontext)(c))
}
