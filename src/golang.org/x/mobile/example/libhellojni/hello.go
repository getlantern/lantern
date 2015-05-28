// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android

package main

// #cgo LDFLAGS: -llog
// #include <android/log.h>
// #include <string.h>
import "C"
import (
	"fmt"
	"unsafe"
)

//export LogHello
func LogHello(name string) {
	fmt.Printf("Hello, %s!\n", name)

	ctag := C.CString("Go")
	cstr := C.CString(fmt.Sprintf("Printing hello message for %q", name))
	C.__android_log_write(C.ANDROID_LOG_INFO, ctag, cstr)
	C.free(unsafe.Pointer(ctag))
	C.free(unsafe.Pointer(cstr))
}
