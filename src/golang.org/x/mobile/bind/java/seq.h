// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef __GO_SEQ_HDR__
#define __GO_SEQ_HDR__

#include <stdint.h>
#include <android/log.h>
// For abort()
#include <stdlib.h>
#include <jni.h>

#define LOG_INFO(...) __android_log_print(ANDROID_LOG_INFO, "go/Seq", __VA_ARGS__)
#define LOG_FATAL(...)                                             \
  {                                                                \
    __android_log_print(ANDROID_LOG_FATAL, "go/Seq", __VA_ARGS__); \
    abort();                                                       \
  }

// Platform specific types
typedef struct nstring {
	// UTF16 or UTF8 Encoded string. When converting from Java string to Go
	// string, UTF16. When converting from Go to Java, UTF8.
	void *chars;
	// length in bytes, regardless of encoding
	jsize len;
} nstring;
typedef struct nbyteslice {
	void *ptr;
	jsize len;
} nbyteslice;
typedef jlong nint;

extern void go_seq_dec_ref(int32_t ref);
extern void go_seq_inc_ref(int32_t ref);
extern int32_t go_seq_to_refnum(JNIEnv *env, jobject o);
extern jobject go_seq_from_refnum(JNIEnv *env, int32_t refnum, jclass proxy_class, jmethodID proxy_cons);

extern void go_seq_maybe_throw_exception(JNIEnv *env, jobject msg);
extern jstring go_seq_get_exception_message(JNIEnv *env);

extern jbyteArray go_seq_to_java_bytearray(JNIEnv *env, nbyteslice s, int copy);
extern nbyteslice go_seq_from_java_bytearray(JNIEnv *env, jbyteArray s, int copy);

extern jstring go_seq_to_java_string(JNIEnv *env, nstring str);
extern nstring go_seq_from_java_string(JNIEnv *env, jstring s);

// push_local_frame retrieves or creates the JNIEnv* for the current thread
// and pushes a JNI reference frame. Must be matched with call to pop_local_frame.
extern JNIEnv *go_seq_push_local_frame(jint cap);
// Pop the current local frame, releasing all JNI local references in it
extern void go_seq_pop_local_frame(JNIEnv *env);

#endif // __GO_SEQ_HDR__
