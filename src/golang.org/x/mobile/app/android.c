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

// Defined in android.go.
extern pthread_cond_t go_started_cond;
extern pthread_mutex_t go_started_mu;
extern int go_started;
extern JavaVM* current_vm;

static int (*_rt0_arm_linux1)(int argc, char** argv);

jint JNI_OnLoad(JavaVM* vm, void* reserved) {
	current_vm = vm;

	JNIEnv* env;
	if ((*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6) != JNI_OK) {
		return -1;
	}

	pthread_mutex_lock(&go_started_mu);
	go_started = 0;
	pthread_mutex_unlock(&go_started_mu);
	pthread_cond_init(&go_started_cond, NULL);

	return JNI_VERSION_1_6;
}

static void* init_go_runtime(void* unused) {
	_rt0_arm_linux1 = (int (*)(int, char**))dlsym(RTLD_DEFAULT, "_rt0_arm_linux1");
	if (_rt0_arm_linux1 == NULL) {
		__android_log_print(ANDROID_LOG_FATAL, "Go", "missing _rt0_arm_linux1");
	}

	// Defensively heap-allocate argv0, for setenv.
	char* argv0 = strdup("gojni");

	// Build argv, including the ELF auxiliary vector.
	struct {
		char* argv[2];
		char* envp[2];
		uint32_t auxv[64];
	} x;
	x.argv[0] = argv0;
	x.argv[1] = NULL;
	x.envp[0] = argv0;
	x.envp[1] = NULL;

	build_auxv(x.auxv, sizeof(x.auxv)/sizeof(uint32_t));
	int32_t argc = 1;
	_rt0_arm_linux1(argc, x.argv);
	return NULL;
}

static void wait_go_runtime() {
	pthread_mutex_lock(&go_started_mu);
	while (go_started == 0) {
		pthread_cond_wait(&go_started_cond, &go_started_mu);
	}
	pthread_mutex_unlock(&go_started_mu);
	__android_log_print(ANDROID_LOG_INFO, "Go", "Runtime started");
}

pthread_t nativeactivity_t;

// Runtime entry point when embedding Go in other libraries.
void InitGoRuntime() {
	pthread_mutex_lock(&go_started_mu);
	go_started = 0;
	pthread_mutex_unlock(&go_started_mu);
	pthread_cond_init(&go_started_cond, NULL);

	pthread_attr_t attr; 
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
	pthread_create(&nativeactivity_t, NULL, init_go_runtime, NULL);
	wait_go_runtime();
}

// Runtime entry point when using NativeActivity.
void ANativeActivity_onCreate(ANativeActivity *activity, void* savedState, size_t savedStateSize) {
	current_vm = activity->vm;

	InitGoRuntime();

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
	activity->callbacks->onNativeWindowResized = onNativeWindowResized;
	activity->callbacks->onNativeWindowRedrawNeeded = onNativeWindowRedrawNeeded;
	activity->callbacks->onNativeWindowDestroyed = onNativeWindowDestroyed;
	activity->callbacks->onInputQueueCreated = onInputQueueCreated;
	activity->callbacks->onInputQueueDestroyed = onInputQueueDestroyed;
	// TODO(crawshaw): Type mismatch for onContentRectChanged.
	//activity->callbacks->onContentRectChanged = onContentRectChanged;
	activity->callbacks->onConfigurationChanged = onConfigurationChanged;
	activity->callbacks->onLowMemory = onLowMemory;

	onCreate(activity);
}

// Runtime entry point when embedding Go in a Java App.
JNIEXPORT void JNICALL
Java_go_Go_run(JNIEnv* env, jclass clazz) {
	init_go_runtime(NULL);
}

// Used by Java initialization code to know when it can use cgocall.
JNIEXPORT void JNICALL
Java_go_Go_waitForRun(JNIEnv* env, jclass clazz) {
	wait_go_runtime();
}
