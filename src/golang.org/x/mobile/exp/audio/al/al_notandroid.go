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
#include <OpenAL/al.h>
#endif

#ifdef GOOS_linux
#include <stdlib.h>
#include <AL/al.h>
#endif
*/
import "C"
import "unsafe"

func alEnable(capability int32) {
	C.alEnable(C.ALenum(capability))
}

func alDisable(capability int32) {
	C.alDisable(C.ALenum(capability))
}

func alIsEnabled(capability int32) bool {
	return C.alIsEnabled(C.ALenum(capability)) == C.AL_TRUE
}

func alGetInteger(k int) int32 {
	return int32(C.alGetInteger(C.ALenum(k)))
}

func alGetIntegerv(k int, v []int32) {
	C.alGetIntegerv(C.ALenum(k), (*C.ALint)(unsafe.Pointer(&v[0])))
}

func alGetFloat(k int) float32 {
	return float32(C.alGetFloat(C.ALenum(k)))
}

func alGetFloatv(k int, v []float32) {
	C.alGetFloatv(C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alGetBoolean(k int) bool {
	return C.alGetBoolean(C.ALenum(k)) == C.AL_TRUE
}

func alGetBooleanv(k int, v []bool) {
	val := make([]C.ALboolean, len(v))
	for i, bv := range v {
		if bv {
			val[i] = C.AL_TRUE
		} else {
			val[i] = C.AL_FALSE
		}
	}
	C.alGetBooleanv(C.ALenum(k), &val[0])
}

func alGetString(v int) string {
	value := C.alGetString(C.ALenum(v))
	return C.GoString((*C.char)(value))
}

func alDistanceModel(v int32) {
	C.alDistanceModel(C.ALenum(v))
}

func alDopplerFactor(v float32) {
	C.alDopplerFactor(C.ALfloat(v))
}

func alDopplerVelocity(v float32) {
	C.alDopplerVelocity(C.ALfloat(v))
}

func alSpeedOfSound(v float32) {
	C.alSpeedOfSound(C.ALfloat(v))
}

func alGetError() int32 {
	return int32(C.alGetError())
}

func alGenSources(n int) []Source {
	s := make([]Source, n)
	C.alGenSources(C.ALsizei(n), (*C.ALuint)(unsafe.Pointer(&s[0])))
	return s
}

func alSourcePlayv(s []Source) {
	C.alSourcePlayv(C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alSourcePausev(s []Source) {
	C.alSourcePausev(C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))

}

func alSourceStopv(s []Source) {
	C.alSourceStopv(C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alSourceRewindv(s []Source) {
	C.alSourceRewindv(C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alDeleteSources(s []Source) {
	C.alDeleteSources(C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alGetSourcei(s Source, k int) int32 {
	var v C.ALint
	C.alGetSourcei(C.ALuint(s), C.ALenum(k), &v)
	return int32(v)
}

func alGetSourcef(s Source, k int) float32 {
	var v C.ALfloat
	C.alGetSourcef(C.ALuint(s), C.ALenum(k), &v)
	return float32(v)
}

func alGetSourcefv(s Source, k int, v []float32) {
	C.alGetSourcefv(C.ALuint(s), C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alSourcei(s Source, k int, v int32) {
	C.alSourcei(C.ALuint(s), C.ALenum(k), C.ALint(v))
}

func alSourcef(s Source, k int, v float32) {
	C.alSourcef(C.ALuint(s), C.ALenum(k), C.ALfloat(v))
}

func alSourcefv(s Source, k int, v []float32) {
	C.alSourcefv(C.ALuint(s), C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alSourceQueueBuffers(s Source, b []Buffer) {
	C.alSourceQueueBuffers(C.ALuint(s), C.ALsizei(len(b)), (*C.ALuint)(unsafe.Pointer(&b[0])))
}

func alSourceUnqueueBuffers(s Source, b []Buffer) {
	C.alSourceUnqueueBuffers(C.ALuint(s), C.ALsizei(len(b)), (*C.ALuint)(unsafe.Pointer(&b[0])))
}

func alGetListenerf(k int) float32 {
	var v C.ALfloat
	C.alGetListenerf(C.ALenum(k), &v)
	return float32(v)
}

func alGetListenerfv(k int, v []float32) {
	C.alGetListenerfv(C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alListenerf(k int, v float32) {
	C.alListenerf(C.ALenum(k), C.ALfloat(v))
}

func alListenerfv(k int, v []float32) {
	C.alListenerfv(C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alGenBuffers(n int) []Buffer {
	s := make([]Buffer, n)
	C.alGenBuffers(C.ALsizei(n), (*C.ALuint)(unsafe.Pointer(&s[0])))
	return s
}

func alDeleteBuffers(b []Buffer) {
	C.alDeleteBuffers(C.ALsizei(len(b)), (*C.ALuint)(unsafe.Pointer(&b[0])))
}

func alGetBufferi(b Buffer, k int) int32 {
	var v C.ALint
	C.alGetBufferi(C.ALuint(b), C.ALenum(k), &v)
	return int32(v)
}

func alBufferData(b Buffer, format uint32, data []byte, freq int32) {
	C.alBufferData(C.ALuint(b), C.ALenum(format), unsafe.Pointer(&data[0]), C.ALsizei(len(data)), C.ALsizei(freq))
}

func alIsBuffer(b Buffer) bool {
	return C.alIsBuffer(C.ALuint(b)) == C.AL_TRUE
}
