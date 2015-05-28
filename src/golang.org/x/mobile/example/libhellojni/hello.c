// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android

// See main.go for commentary.

#include <android/log.h>
#include <jni.h>
#include <limits.h>
#include "_cgo_export.h"

JNIEXPORT void JNICALL
Java_demo_Demo_hello(JNIEnv* env, jclass clazz, jstring jname) {
	// Turn Java's UTF16 string into (almost) UTF8.
	const char *name = (*env)->GetStringUTFChars(env, jname, 0);

	GoString go_name;
	go_name.p = (char*)name;
	go_name.n = (*env)->GetStringUTFLength(env, jname);

	// Call into Go.
	LogHello(go_name);

	(*env)->ReleaseStringUTFChars(env, jname, name);
}
