// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package mobileinit

/*
#include <jni.h>
#include <stdlib.h>

// current_vm is stored to initialize other cgo packages.
//
// As all the Go packages in a program form a single shared library,
// there can only be one JNI_OnLoad function for initialization. In
// OpenJDK there is JNI_GetCreatedJavaVMs, but this is not available
// on android.
JavaVM* current_vm;

// current_ctx is Android's android.context.Context. May be NULL.
jobject current_ctx;

// Set current_vm and current_ctx. The ctx passed in must be a global
// reference instance.
void set_vm_ctx(JavaVM* vm, jobject ctx) {
	current_vm = vm;
	current_ctx = ctx;
	// TODO: check leak
}
*/
import "C"

import "unsafe"

// SetCurrentContext populates the global Context object with the specified
// current JavaVM instance (vm) and android.context.Context object (ctx).
// The android.context.Context object must be a global reference.
func SetCurrentContext(vm, ctx unsafe.Pointer) {
	C.set_vm_ctx((*C.JavaVM)(vm), (C.jobject)(ctx))
}

// TODO(hyangah): should the app package have Context? It may be useful for
// external packages that need to access android context and vm.

// Context holds global OS-specific context.
//
// Its extra methods are deliberately difficult to access because they must be
// used with care. Their use implies the use of cgo, which probably requires
// you understand the initialization process in the app package. Also care must
// be taken to write both Android, iOS, and desktop-testing versions to
// maintain portability.
type Context struct{}

// AndroidContext returns a jobject for the app android.context.Context.
func (Context) AndroidContext() unsafe.Pointer {
	return unsafe.Pointer(C.current_ctx)
}

// JavaVM returns a JNI *JavaVM.
func (Context) JavaVM() unsafe.Pointer {
	return unsafe.Pointer(C.current_vm)
}
