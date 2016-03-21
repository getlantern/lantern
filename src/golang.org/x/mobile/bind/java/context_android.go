// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package java // import "golang.org/x/mobile/bind/java"

// #cgo LDFLAGS: -llog
//
//#include <jni.h>
import "C"

import (
	"unsafe"

	"golang.org/x/mobile/internal/mobileinit"
)

//export setContext
func setContext(vm *C.JavaVM, ctx C.jobject) {
	mobileinit.SetCurrentContext(unsafe.Pointer(vm), unsafe.Pointer(ctx))
}
