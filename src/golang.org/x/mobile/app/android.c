// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android

#include <android/asset_manager_jni.h>
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
		LOG_FATAL("cannot find %s", class_name);
		return NULL;
	}
	return clazz;
}

static jmethodID find_method(JNIEnv *env, jclass clazz, const char *name, const char *sig) {
	jmethodID m = (*env)->GetMethodID(env, clazz, name, sig);
	if (m == 0) {
		LOG_FATAL("cannot find method %s %s", name, sig);
		return 0;
	}
	return m;
}

static jclass app_class_loader;
static jmethodID app_find_class_fn;

// app_find_class finds the given class using the class loader cached
// during JNI_OnLoad. This allows the bind/java package and other
// part of JNI to dynamically load java classes from non-Java threads.
//
// http://developer.android.com/training/articles/perf-jni.html#faq_FindClass
jclass app_find_class(JNIEnv* env, const char* name) {
    jstring classname = (*env)->NewStringUTF(env, name);
    return (*env)->CallObjectMethod(env, app_class_loader, app_find_class_fn, classname);
}

jint JNI_OnLoad(JavaVM* vm, void* reserved) {
	JNIEnv* env;
	if ((*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6) != JNI_OK) {
		return -1;
	}

	current_vm = vm;
	current_ctx = NULL;
	current_native_activity = NULL;

	// cache the class loader for use in JNI threads.
	jclass a_clazz = (*env)->FindClass(env, "go/Go");
	jclass clazz_clazz = (*env)->GetObjectClass(env, a_clazz);
	jclass class_loader_clazz = (*env)->FindClass(env, "java/lang/ClassLoader");
	jmethodID get_class_loader = (*env)->GetMethodID(env, clazz_clazz, "getClassLoader",
			"()Ljava/lang/ClassLoader;");
	jclass loader = (*env)->CallObjectMethod(env, a_clazz, get_class_loader);
	app_class_loader = (*env)->NewGlobalRef(env, loader);

	app_find_class_fn = (*env)->GetMethodID(env, class_loader_clazz, "findClass",
		    "(Ljava/lang/String;)Ljava/lang/Class;");

	return JNI_VERSION_1_6;
}

static void init_from_context() {
	if (current_ctx == NULL) {
		return;
	}

	int attached = 0;
	JNIEnv* env;
	switch ((*current_vm)->GetEnv(current_vm, (void**)&env, JNI_VERSION_1_6)) {
	case JNI_OK:
		break;
	case JNI_EDETACHED:
		if ((*current_vm)->AttachCurrentThread(current_vm, &env, 0) != 0) {
			LOG_FATAL("cannot attach JVM");
		}
		attached = 1;
		break;
	case JNI_EVERSION:
		LOG_FATAL("bad JNI version");
	}

	// String path = context.getCacheDir().getAbsolutePath();
	jclass context_clazz = find_class(env, "android/content/Context");
	jmethodID getcachedir = find_method(env, context_clazz, "getCacheDir", "()Ljava/io/File;");
	jobject file = (*env)->CallObjectMethod(env, current_ctx, getcachedir, NULL);
	jclass file_clazz = find_class(env, "java/io/File");
	jmethodID getabsolutepath = find_method(env, file_clazz, "getAbsolutePath", "()Ljava/lang/String;");
	jstring jpath = (jstring)(*env)->CallObjectMethod(env, file, getabsolutepath, NULL);
	const char* path = (*env)->GetStringUTFChars(env, jpath, NULL);
	if (setenv("TMPDIR", path, 1) != 0) {
		LOG_INFO("setenv(\"TMPDIR\", \"%s\", 1) failed: %d", path, errno);
	}
	(*env)->ReleaseStringUTFChars(env, jpath, path);

	if (attached) {
		(*current_vm)->DetachCurrentThread(current_vm);
	}
}

// has_prefix_key returns 1 if s starts with prefix.
static int has_prefix(const char *s, const char* prefix) {
	while (*prefix) {
		if (*prefix++ != *s++)
			return 0;
	}
	return 1;
}

// getenv_raw searches environ for name prefix and returns the string pair.
// For example, getenv_raw("PATH=") returns "PATH=/bin".
// If no entry is found, the name prefix is returned. For example "PATH=".
static const char* getenv_raw(const char *name) {
	extern char** environ;
	char** env = environ;

	for (env = environ; *env; env++) {
		if (has_prefix(*env, name)) {
			return *env;
		}
	}
	return name;
}

static void* call_main_and_wait() {
	init_from_context();
	uintptr_t mainPC = (uintptr_t)dlsym(RTLD_DEFAULT, "main.main");
	if (!mainPC) {
		LOG_FATAL("missing main.main");
	}
	callMain(mainPC);
}

// Runtime entry point when using NativeActivity.
void ANativeActivity_onCreate(ANativeActivity *activity, void* savedState, size_t savedStateSize) {
	current_native_activity = activity;
	if (current_ctx == NULL) {
		// Note that activity->clazz is mis-named.
		current_vm = activity->vm;
		current_ctx = (*activity->env)->NewGlobalRef(activity->env, activity->clazz);
		call_main_and_wait();
	}

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
Java_go_Go_run(JNIEnv* env, jclass clazz, jobject ctx) {
	current_ctx = (*env)->NewGlobalRef(env, ctx);

	if (current_ctx != NULL) {
		// Init asset_manager.
		jclass context_clazz = find_class(env, "android/content/Context");
		jmethodID getassets = find_method(
			env, context_clazz, "getAssets", "()Landroid/content/res/AssetManager;");

		// Prevent the java AssetManager from being GC'd
		jobject asset_manager_ref = (*env)->NewGlobalRef(
			env, (*env)->CallObjectMethod(env, current_ctx, getassets));
		asset_manager = AAssetManager_fromJava(env, asset_manager_ref);
	}

	call_main_and_wait();
}
