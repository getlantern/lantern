// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jni.h>
#include "seq.h"

JNIEXPORT void JNICALL
Java_go_Seq_setContext(JNIEnv* env, jclass clazz, jobject ctx) {
	JavaVM* vm;
	if ((*env)->GetJavaVM(env, &vm) != 0) {
		LOG_FATAL("failed to get JavaVM");
	}
	setContext(vm, (*env)->NewGlobalRef(env, ctx));
}
