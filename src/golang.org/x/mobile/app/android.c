// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android

#include <android/log.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <jni.h>
#include <pthread.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "_cgo_export.h"

#define LOG_INFO(...) __android_log_print(ANDROID_LOG_INFO, "Go", __VA_ARGS__)
#define LOG_FATAL(...) __android_log_print(ANDROID_LOG_FATAL, "Go", __VA_ARGS__)

static jclass find_class(JNIEnv *env, const char *class_name) {
	jclass clazz = (*env)->FindClass(env, class_name);
	if (clazz == NULL) {
		(*env)->ExceptionClear(env);
		LOG_FATAL("cannot find %s", class_name);
		return NULL;
	}
	return clazz;
}

static jmethodID find_method(JNIEnv *env, jclass clazz, const char *name, const char *sig) {
	jmethodID m = (*env)->GetMethodID(env, clazz, name, sig);
	if (m == 0) {
		(*env)->ExceptionClear(env);
		LOG_FATAL("cannot find method %s %s", name, sig);
		return 0;
	}
	return m;
}

jint JNI_OnLoad(JavaVM* vm, void* reserved) {
	JNIEnv* env;
	if ((*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6) != JNI_OK) {
		return -1;
	}

	// Load classes here, which uses the correct ClassLoader.
	current_ctx_clazz = find_class(env, "org/golang/app/GoNativeActivity");
	current_ctx_clazz = (jclass)(*env)->NewGlobalRef(env, current_ctx_clazz);

	return JNI_VERSION_1_6;
}

// Entry point from our subclassed NativeActivity.
//
// By here, the Go runtime has been initialized (as we are running in
// -buildmode=c-shared) but main.main hasn't been called yet.
void ANativeActivity_onCreate(ANativeActivity *activity, void* savedState, size_t savedStateSize) {
	JNIEnv* env = activity->env;

	// Note that activity->clazz is mis-named.
	JavaVM* current_vm = activity->vm;
	jobject current_ctx = activity->clazz;

	setCurrentContext(current_vm, (*env)->NewGlobalRef(env, current_ctx));

	// Set TMPDIR.
	jmethodID gettmpdir = find_method(env, current_ctx_clazz, "getTmpdir", "()Ljava/lang/String;");
	jstring jpath = (jstring)(*env)->CallObjectMethod(env, current_ctx, gettmpdir, NULL);
	const char* tmpdir = (*env)->GetStringUTFChars(env, jpath, NULL);
	if (setenv("TMPDIR", tmpdir, 1) != 0) {
		LOG_INFO("setenv(\"TMPDIR\", \"%s\", 1) failed: %d", tmpdir, errno);
	}
	(*env)->ReleaseStringUTFChars(env, jpath, tmpdir);

	// Call the Go main.main.
	uintptr_t mainPC = (uintptr_t)dlsym(RTLD_DEFAULT, "main.main");
	if (!mainPC) {
		LOG_FATAL("missing main.main");
	}
	callMain(mainPC);

	// These functions match the methods on Activity, described at
	// http://developer.android.com/reference/android/app/Activity.html
	activity->callbacks->onStart = onStart;
	activity->callbacks->onResume = onResume;
	activity->callbacks->onSaveInstanceState = onSaveInstanceState;
	activity->callbacks->onPause = onPause;
	activity->callbacks->onStop = onStop;
	activity->callbacks->onDestroy = onDestroy;
	activity->callbacks->onWindowFocusChanged = onWindowFocusChanged;
	activity->callbacks->onNativeWindowCreated = onNativeWindowCreated;
	activity->callbacks->onNativeWindowRedrawNeeded = onNativeWindowRedrawNeeded;
	activity->callbacks->onNativeWindowDestroyed = onNativeWindowDestroyed;
	activity->callbacks->onInputQueueCreated = onInputQueueCreated;
	activity->callbacks->onInputQueueDestroyed = onInputQueueDestroyed;
	activity->callbacks->onConfigurationChanged = onConfigurationChanged;
	activity->callbacks->onLowMemory = onLowMemory;

	// Note that onNativeWindowResized is not called on resize. Avoid it.
	// https://code.google.com/p/android/issues/detail?id=180645
	onCreate(activity);
}
