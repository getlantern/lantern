// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package al

/*
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <jni.h>
#include <limits.h>
#include <AL/al.h>
#include <AL/alc.h>

void al_init(uintptr_t java_vm, uintptr_t jni_env, jobject context, void** handle) {
  JavaVM* vm = (JavaVM*)java_vm;
  JNIEnv* env = (JNIEnv*)jni_env;

  jclass android_content_Context = (*env)->FindClass(env, "android/content/Context");
  jmethodID get_package_name = (*env)->GetMethodID(env, android_content_Context, "getPackageName", "()Ljava/lang/String;");
  jstring package_name = (*env)->CallObjectMethod(env, context, get_package_name);
  const char *cpackage_name = (*env)->GetStringUTFChars(env, package_name, 0);

  char lib_path[PATH_MAX] = "/data/data/";
  strlcat(lib_path, cpackage_name, sizeof(lib_path));
  strlcat(lib_path, "/lib/libopenal.so", sizeof(lib_path));
  *handle = dlopen(lib_path, RTLD_LAZY);
  (*env)->ReleaseStringUTFChars(env, package_name, cpackage_name);
}

void call_alEnable(LPALENABLE fn, ALenum capability) {
  fn(capability);
}

void call_alDisable(LPALDISABLE fn, ALenum capability) {
  fn(capability);
}

ALboolean call_alIsEnabled(LPALISENABLED fn, ALenum capability) {
  return fn(capability);
}

ALint call_alGetInteger(LPALGETINTEGER fn, ALenum p) {
  return fn(p);
}

void call_alGetIntegerv(LPALGETINTEGERV fn, ALenum p, ALint* v) {
  fn(p, v);
}

ALfloat call_alGetFloat(LPALGETFLOAT fn, ALenum p) {
  return fn(p);
}

void call_alGetFloatv(LPALGETFLOATV fn, ALenum p, ALfloat* v) {
  fn(p, v);
}

ALboolean call_alGetBoolean(LPALGETBOOLEAN fn, ALenum p) {
  return fn(p);
}

void call_alGetBooleanv(LPALGETBOOLEANV fn, ALenum p, ALboolean* v) {
  fn(p, v);
}

const char* call_alGetString(LPALGETSTRING fn, ALenum p) {
  return fn(p);
}

void call_alDistanceModel(LPALDISTANCEMODEL fn, ALenum v) {
  fn(v);
}

void call_alDopplerFactor(LPALDOPPLERFACTOR fn, ALfloat v) {
  fn(v);
}

void call_alDopplerVelocity(LPALDOPPLERVELOCITY fn, ALfloat v) {
  fn(v);
}

void call_alSpeedOfSound(LPALSPEEDOFSOUND fn, ALfloat v) {
  fn(v);
}

ALint call_alGetError(LPALGETERROR fn) {
  return fn();
}

void call_alGenSources(LPALGENSOURCES fn, ALsizei n, ALuint* s) {
  fn(n, s);
}

void call_alSourcePlayv(LPALSOURCEPLAYV fn, ALsizei n, const ALuint* s) {
  fn(n, s);
}

void call_alSourcePausev(LPALSOURCEPAUSEV fn, ALsizei n, const ALuint* s) {
  fn(n, s);
}

void call_alSourceStopv(LPALSOURCESTOPV fn, ALsizei n, const ALuint* s) {
  fn(n, s);
}

void call_alSourceRewindv(LPALSOURCEREWINDV fn, ALsizei n, const ALuint* s) {
  fn(n, s);
}

void call_alDeleteSources(LPALDELETESOURCES fn, ALsizei n, const ALuint* s) {
  fn(n, s);
}

void call_alGetSourcei(LPALGETSOURCEI fn, ALuint s, ALenum k, ALint* v) {
  fn(s, k, v);
}

void call_alGetSourcef(LPALGETSOURCEF fn, ALuint s, ALenum k, ALfloat* v) {
  fn(s, k, v);
}

void call_alGetSourcefv(LPALGETSOURCEFV fn, ALuint s, ALenum k, ALfloat* v) {
  fn(s, k, v);
}

void call_alSourcei(LPALSOURCEI fn, ALuint s, ALenum k, ALint v) {
  fn(s, k, v);
}

void call_alSourcef(LPALSOURCEF fn, ALuint s, ALenum k, ALfloat v) {
  fn(s, k, v);
}

void call_alSourcefv(LPALSOURCEFV fn, ALuint s, ALenum k, const ALfloat* v) {
  fn(s, k, v);
}

void call_alSourceQueueBuffers(LPALSOURCEQUEUEBUFFERS fn, ALuint s, ALsizei n, const ALuint* b) {
  fn(s, n, b);
}

void call_alSourceUnqueueBuffers(LPALSOURCEUNQUEUEBUFFERS fn, ALuint s, ALsizei n, ALuint* b) {
  fn(s, n, b);
}

void call_alGetListenerf(LPALGETLISTENERF fn, ALenum k, ALfloat* v) {
  fn(k, v);
}

void call_alGetListenerfv(LPALLISTENERFV fn, ALenum k, ALfloat* v) {
  fn(k, v);
}

void call_alListenerf(LPALLISTENERF fn, ALenum k, ALfloat v) {
  fn(k, v);
}

void call_alListenerfv(LPALLISTENERFV fn, ALenum k, const ALfloat* v) {
  fn(k, v);
}

void call_alGenBuffers(LPALGENBUFFERS fn, ALsizei n, ALuint* v) {
  fn(n, v);
}

void call_alDeleteBuffers(LPALDELETEBUFFERS fn, ALsizei n, ALuint* v) {
  fn(n, v);
}

void call_alGetBufferi(LPALGETBUFFERI fn, ALuint b, ALenum k, ALint* v) {
  fn(b, k, v);
}

void call_alBufferData(LPALBUFFERDATA fn, ALuint b, ALenum format, const ALvoid* data, ALsizei size, ALsizei freq) {
  fn(b, format, data, size, freq);
}

ALboolean call_alIsBuffer(LPALISBUFFER fn, ALuint b) {
  return fn(b);
}
*/
import "C"
import (
	"errors"
	"log"
	"unsafe"

	"golang.org/x/mobile/internal/mobileinit"
)

var (
	alHandle                   unsafe.Pointer
	alEnableFunc               C.LPALENABLE
	alDisableFunc              C.LPALDISABLE
	alIsEnabledFunc            C.LPALISENABLED
	alGetIntegerFunc           C.LPALGETINTEGER
	alGetIntegervFunc          C.LPALGETINTEGERV
	alGetFloatFunc             C.LPALGETFLOAT
	alGetFloatvFunc            C.LPALGETFLOATV
	alGetBooleanFunc           C.LPALGETBOOLEAN
	alGetBooleanvFunc          C.LPALGETBOOLEANV
	alGetStringFunc            C.LPALGETSTRING
	alDistanceModelFunc        C.LPALDISTANCEMODEL
	alDopplerFactorFunc        C.LPALDOPPLERFACTOR
	alDopplerVelocityFunc      C.LPALDOPPLERVELOCITY
	alSpeedOfSoundFunc         C.LPALSPEEDOFSOUND
	alGetErrorFunc             C.LPALGETERROR
	alGenSourcesFunc           C.LPALGENSOURCES
	alSourcePlayvFunc          C.LPALSOURCEPLAYV
	alSourcePausevFunc         C.LPALSOURCEPAUSEV
	alSourceStopvFunc          C.LPALSOURCESTOPV
	alSourceRewindvFunc        C.LPALSOURCEREWINDV
	alDeleteSourcesFunc        C.LPALDELETESOURCES
	alGetSourceiFunc           C.LPALGETSOURCEI
	alGetSourcefFunc           C.LPALGETSOURCEF
	alGetSourcefvFunc          C.LPALGETSOURCEFV
	alSourceiFunc              C.LPALSOURCEI
	alSourcefFunc              C.LPALSOURCEF
	alSourcefvFunc             C.LPALSOURCEFV
	alSourceQueueBuffersFunc   C.LPALSOURCEQUEUEBUFFERS
	alSourceUnqueueBuffersFunc C.LPALSOURCEUNQUEUEBUFFERS
	alGetListenerfFunc         C.LPALGETLISTENERF
	alGetListenerfvFunc        C.LPALGETLISTENERFV
	alListenerfFunc            C.LPALLISTENERF
	alListenerfvFunc           C.LPALLISTENERFV
	alGenBuffersFunc           C.LPALGENBUFFERS
	alDeleteBuffersFunc        C.LPALDELETEBUFFERS
	alGetBufferiFunc           C.LPALGETBUFFERI
	alBufferDataFunc           C.LPALBUFFERDATA
	alIsBufferFunc             C.LPALISBUFFER

	alcGetErrorFunc           C.LPALCGETERROR
	alcOpenDeviceFunc         C.LPALCOPENDEVICE
	alcCloseDeviceFunc        C.LPALCCLOSEDEVICE
	alcCreateContextFunc      C.LPALCCREATECONTEXT
	alcMakeContextCurrentFunc C.LPALCMAKECONTEXTCURRENT
	alcDestroyContextFunc     C.LPALCDESTROYCONTEXT
)

func initAL() {
	err := mobileinit.RunOnJVM(func(vm, env, ctx uintptr) error {
		C.al_init(C.uintptr_t(vm), C.uintptr_t(env), C.jobject(ctx), &alHandle)
		if alHandle == nil {
			return errors.New("al: cannot load libopenal.so")
		}
		return nil
	})
	if err != nil {
		log.Fatalf("al: %v", err)
	}

	alEnableFunc = C.LPALENABLE(fn("alEnable"))
	alDisableFunc = C.LPALDISABLE(fn("alDisable"))
	alIsEnabledFunc = C.LPALISENABLED(fn("alIsEnabled"))
	alGetIntegerFunc = C.LPALGETINTEGER(fn("alGetInteger"))
	alGetIntegervFunc = C.LPALGETINTEGERV(fn("alGetIntegerv"))
	alGetFloatFunc = C.LPALGETFLOAT(fn("alGetFloat"))
	alGetFloatvFunc = C.LPALGETFLOATV(fn("alGetFloatv"))
	alGetBooleanFunc = C.LPALGETBOOLEAN(fn("alGetBoolean"))
	alGetBooleanvFunc = C.LPALGETBOOLEANV(fn("alGetBooleanv"))
	alGetStringFunc = C.LPALGETSTRING(fn("alGetString"))
	alDistanceModelFunc = C.LPALDISTANCEMODEL(fn("alDistanceModel"))
	alDopplerFactorFunc = C.LPALDOPPLERFACTOR(fn("alDopplerFactor"))
	alDopplerVelocityFunc = C.LPALDOPPLERVELOCITY(fn("alDopplerVelocity"))
	alSpeedOfSoundFunc = C.LPALSPEEDOFSOUND(fn("alSpeedOfSound"))
	alGetErrorFunc = C.LPALGETERROR(fn("alGetError"))
	alGenSourcesFunc = C.LPALGENSOURCES(fn("alGenSources"))
	alSourcePlayvFunc = C.LPALSOURCEPLAYV(fn("alSourcePlayv"))
	alSourcePausevFunc = C.LPALSOURCEPAUSEV(fn("alSourcePausev"))
	alSourceStopvFunc = C.LPALSOURCESTOPV(fn("alSourceStopv"))
	alSourceRewindvFunc = C.LPALSOURCEREWINDV(fn("alSourceRewindv"))
	alDeleteSourcesFunc = C.LPALDELETESOURCES(fn("alDeleteSources"))
	alGetSourceiFunc = C.LPALGETSOURCEI(fn("alGetSourcei"))
	alGetSourcefFunc = C.LPALGETSOURCEF(fn("alGetSourcef"))
	alGetSourcefvFunc = C.LPALGETSOURCEFV(fn("alGetSourcefv"))
	alSourceiFunc = C.LPALSOURCEI(fn("alSourcei"))
	alSourcefFunc = C.LPALSOURCEF(fn("alSourcef"))
	alSourcefvFunc = C.LPALSOURCEFV(fn("alSourcefv"))
	alSourceQueueBuffersFunc = C.LPALSOURCEQUEUEBUFFERS(fn("alSourceQueueBuffers"))
	alSourceUnqueueBuffersFunc = C.LPALSOURCEUNQUEUEBUFFERS(fn("alSourceUnqueueBuffers"))
	alGetListenerfFunc = C.LPALGETLISTENERF(fn("alGetListenerf"))
	alGetListenerfvFunc = C.LPALGETLISTENERFV(fn("alGetListenerfv"))
	alListenerfFunc = C.LPALLISTENERF(fn("alListenerf"))
	alListenerfvFunc = C.LPALLISTENERFV(fn("alListenerfv"))
	alGenBuffersFunc = C.LPALGENBUFFERS(fn("alGenBuffers"))
	alDeleteBuffersFunc = C.LPALDELETEBUFFERS(fn("alDeleteBuffers"))
	alGetBufferiFunc = C.LPALGETBUFFERI(fn("alGetBufferi"))
	alBufferDataFunc = C.LPALBUFFERDATA(fn("alBufferData"))
	alIsBufferFunc = C.LPALISBUFFER(fn("alIsBuffer"))

	alcGetErrorFunc = C.LPALCGETERROR(fn("alcGetError"))
	alcOpenDeviceFunc = C.LPALCOPENDEVICE(fn("alcOpenDevice"))
	alcCloseDeviceFunc = C.LPALCCLOSEDEVICE(fn("alcCloseDevice"))
	alcCreateContextFunc = C.LPALCCREATECONTEXT(fn("alcCreateContext"))
	alcMakeContextCurrentFunc = C.LPALCMAKECONTEXTCURRENT(fn("alcMakeContextCurrent"))
	alcDestroyContextFunc = C.LPALCDESTROYCONTEXT(fn("alcDestroyContext"))
}

func fn(fname string) unsafe.Pointer {
	name := C.CString(fname)
	defer C.free(unsafe.Pointer(name))

	p := C.dlsym(alHandle, name)
	if uintptr(p) == 0 {
		log.Fatalf("al: couldn't dlsym %q", fname)
	}
	return p
}

func alEnable(capability int32) {
	C.call_alEnable(alEnableFunc, C.ALenum(capability))
}

func alDisable(capability int32) {
	C.call_alDisable(alDisableFunc, C.ALenum(capability))
}

func alIsEnabled(capability int32) bool {
	return C.call_alIsEnabled(alIsEnabledFunc, C.ALenum(capability)) == C.AL_TRUE
}

func alGetInteger(k int) int32 {
	return int32(C.call_alGetInteger(alGetIntegerFunc, C.ALenum(k)))
}

func alGetIntegerv(k int, v []int32) {
	C.call_alGetIntegerv(alGetIntegervFunc, C.ALenum(k), (*C.ALint)(unsafe.Pointer(&v[0])))
}

func alGetFloat(k int) float32 {
	return float32(C.call_alGetFloat(alGetFloatFunc, C.ALenum(k)))
}

func alGetFloatv(k int, v []float32) {
	C.call_alGetFloatv(alGetFloatvFunc, C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alGetBoolean(k int) bool {
	return C.call_alGetBoolean(alGetBooleanFunc, C.ALenum(k)) == C.AL_TRUE
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
	C.call_alGetBooleanv(alGetBooleanvFunc, C.ALenum(k), &val[0])
}

func alGetString(v int) string {
	value := C.call_alGetString(alGetStringFunc, C.ALenum(v))
	return C.GoString(value)
}

func alDistanceModel(v int32) {
	C.call_alDistanceModel(alDistanceModelFunc, C.ALenum(v))
}

func alDopplerFactor(v float32) {
	C.call_alDopplerFactor(alDopplerFactorFunc, C.ALfloat(v))
}

func alDopplerVelocity(v float32) {
	C.call_alDopplerVelocity(alDopplerVelocityFunc, C.ALfloat(v))
}

func alSpeedOfSound(v float32) {
	C.call_alSpeedOfSound(alSpeedOfSoundFunc, C.ALfloat(v))
}

func alGetError() int32 {
	return int32(C.call_alGetError(alGetErrorFunc))
}

func alGenSources(n int) []Source {
	s := make([]Source, n)
	C.call_alGenSources(alGenSourcesFunc, C.ALsizei(n), (*C.ALuint)(unsafe.Pointer(&s[0])))
	return s
}

func alSourcePlayv(s []Source) {
	C.call_alSourcePlayv(alSourcePlayvFunc, C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alSourcePausev(s []Source) {
	C.call_alSourcePausev(alSourcePausevFunc, C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alSourceStopv(s []Source) {
	C.call_alSourceStopv(alSourceStopvFunc, C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alSourceRewindv(s []Source) {
	C.call_alSourceRewindv(alSourceRewindvFunc, C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alDeleteSources(s []Source) {
	C.call_alDeleteSources(alDeleteSourcesFunc, C.ALsizei(len(s)), (*C.ALuint)(unsafe.Pointer(&s[0])))
}

func alGetSourcei(s Source, k int) int32 {
	var v C.ALint
	C.call_alGetSourcei(alGetSourceiFunc, C.ALuint(s), C.ALenum(k), &v)
	return int32(v)
}

func alGetSourcef(s Source, k int) float32 {
	var v C.ALfloat
	C.call_alGetSourcef(alGetSourcefFunc, C.ALuint(s), C.ALenum(k), &v)
	return float32(v)
}

func alGetSourcefv(s Source, k int, v []float32) {
	C.call_alGetSourcefv(alGetSourcefvFunc, C.ALuint(s), C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alSourcei(s Source, k int, v int32) {
	C.call_alSourcei(alSourcefFunc, C.ALuint(s), C.ALenum(k), C.ALint(v))
}

func alSourcef(s Source, k int, v float32) {
	C.call_alSourcef(alSourcefFunc, C.ALuint(s), C.ALenum(k), C.ALfloat(v))
}

func alSourcefv(s Source, k int, v []float32) {
	C.call_alSourcefv(alSourcefvFunc, C.ALuint(s), C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alSourceQueueBuffers(s Source, b []Buffer) {
	C.call_alSourceQueueBuffers(alSourceQueueBuffersFunc, C.ALuint(s), C.ALsizei(len(b)), (*C.ALuint)(unsafe.Pointer(&b[0])))
}

func alSourceUnqueueBuffers(s Source, b []Buffer) {
	C.call_alSourceUnqueueBuffers(alSourceUnqueueBuffersFunc, C.ALuint(s), C.ALsizei(len(b)), (*C.ALuint)(unsafe.Pointer(&b[0])))
}

func alGetListenerf(k int) float32 {
	var v C.ALfloat
	C.call_alGetListenerf(alListenerfFunc, C.ALenum(k), &v)
	return float32(v)
}

func alGetListenerfv(k int, v []float32) {
	C.call_alGetListenerfv(alGetListenerfvFunc, C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alListenerf(k int, v float32) {
	C.call_alListenerf(alListenerfFunc, C.ALenum(k), C.ALfloat(v))
}

func alListenerfv(k int, v []float32) {
	C.call_alListenerfv(alListenerfvFunc, C.ALenum(k), (*C.ALfloat)(unsafe.Pointer(&v[0])))
}

func alGenBuffers(n int) []Buffer {
	s := make([]Buffer, n)
	C.call_alGenBuffers(alGenBuffersFunc, C.ALsizei(n), (*C.ALuint)(unsafe.Pointer(&s[0])))
	return s
}

func alDeleteBuffers(b []Buffer) {
	C.call_alDeleteBuffers(alDeleteBuffersFunc, C.ALsizei(len(b)), (*C.ALuint)(unsafe.Pointer(&b[0])))
}

func alGetBufferi(b Buffer, k int) int32 {
	var v C.ALint
	C.call_alGetBufferi(alGetBufferiFunc, C.ALuint(b), C.ALenum(k), &v)
	return int32(v)
}

func alBufferData(b Buffer, format uint32, data []byte, freq int32) {
	C.call_alBufferData(alBufferDataFunc, C.ALuint(b), C.ALenum(format), unsafe.Pointer(&data[0]), C.ALsizei(len(data)), C.ALsizei(freq))
}

func alIsBuffer(b Buffer) bool {
	return C.call_alIsBuffer(alIsBufferFunc, C.ALuint(b)) == C.AL_TRUE
}
