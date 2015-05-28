// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android

/*
Android Apps are built with -buildmode=c-shared. They are loaded by a
running Java process.

Before any entry point is reached, a global constructor initializes the
Go runtime, calling all Go init functions. All cgo calls will block
until this is complete. Next JNI_OnLoad is called. When that is
complete, one of two entry points is called.

All-Go apps built using NativeActivity enter at ANativeActivity_onCreate.
Go libraries, such as those built with gomobild bind, enter from Java at
Java_go_Go_run.

Both entry points make a cgo call that calls the Go main and blocks
until app.Run is called.
*/

package app

/*
#cgo LDFLAGS: -llog -landroid

#include <android/log.h>
#include <android/asset_manager.h>
#include <android/configuration.h>
#include <android/native_activity.h>

#include <jni.h>
#include <pthread.h>
#include <stdlib.h>

// current_vm is stored to initialize other cgo packages.
//
// As all the Go packages in a program form a single shared library,
// there can only be one JNI_OnLoad function for iniitialization. In
// OpenJDK there is JNI_GetCreatedJavaVMs, but this is not available
// on android.
JavaVM* current_vm;

// current_ctx is Android's android.context.Context. May be NULL.
jobject current_ctx;

jclass app_find_class(JNIEnv* env, const char* name);

// current_native_activity is the Android ANativeActivity. May be NULL.
ANativeActivity* current_native_activity;

// asset_manager is the asset manager of the app.
// For all-Go app, this is initialized in onCreate.
// For go library app, this is set from the context passed to Go.run.
AAssetManager* asset_manager;
*/
import "C"
import (
	"fmt"
	"io"
	"log"
	"os"
	"runtime"
	"unsafe"

	"golang.org/x/mobile/app/internal/callfn"
	"golang.org/x/mobile/geom"
)

//export callMain
func callMain(mainPC uintptr) {
	for _, name := range []string{"TMPDIR", "PATH", "LD_LIBRARY_PATH"} {
		n := C.CString(name)
		os.Setenv(name, C.GoString(C.getenv(n)))
		C.free(unsafe.Pointer(n))
	}
	go callfn.CallFn(mainPC)
	<-mainCalled
	log.Print("app.Run called")
}

//export onCreate
func onCreate(activity *C.ANativeActivity) {
	C.asset_manager = activity.assetManager

	config := C.AConfiguration_new()
	C.AConfiguration_fromAssetManager(config, activity.assetManager)
	density := C.AConfiguration_getDensity(config)
	C.AConfiguration_delete(config)

	var dpi int
	switch density {
	case C.ACONFIGURATION_DENSITY_DEFAULT:
		dpi = 160
	case C.ACONFIGURATION_DENSITY_LOW,
		C.ACONFIGURATION_DENSITY_MEDIUM,
		213, // C.ACONFIGURATION_DENSITY_TV
		C.ACONFIGURATION_DENSITY_HIGH,
		320, // ACONFIGURATION_DENSITY_XHIGH
		480, // ACONFIGURATION_DENSITY_XXHIGH
		640: // ACONFIGURATION_DENSITY_XXXHIGH
		dpi = int(density)
	case C.ACONFIGURATION_DENSITY_NONE:
		log.Print("android device reports no screen density")
		dpi = 72
	default:
		log.Print("android device reports unknown density: %d", density)
		dpi = int(density) // This is a guess.
	}

	geom.PixelsPerPt = float32(dpi) / 72
}

//export onStart
func onStart(activity *C.ANativeActivity) {
}

//export onResume
func onResume(activity *C.ANativeActivity) {
}

//export onSaveInstanceState
func onSaveInstanceState(activity *C.ANativeActivity, outSize *C.size_t) unsafe.Pointer {
	return nil
}

//export onPause
func onPause(activity *C.ANativeActivity) {
}

//export onStop
func onStop(activity *C.ANativeActivity) {
}

//export onDestroy
func onDestroy(activity *C.ANativeActivity) {
}

//export onWindowFocusChanged
func onWindowFocusChanged(activity *C.ANativeActivity, hasFocus int) {
}

//export onNativeWindowCreated
func onNativeWindowCreated(activity *C.ANativeActivity, w *C.ANativeWindow) {
	windowCreated <- w
}

//export onNativeWindowResized
func onNativeWindowResized(activity *C.ANativeActivity, window *C.ANativeWindow) {
}

//export onNativeWindowRedrawNeeded
func onNativeWindowRedrawNeeded(activity *C.ANativeActivity, window *C.ANativeWindow) {
	windowRedrawNeeded <- window
}

//export onNativeWindowDestroyed
func onNativeWindowDestroyed(activity *C.ANativeActivity, window *C.ANativeWindow) {
	windowDestroyed <- true
}

var queue *C.AInputQueue

//export onInputQueueCreated
func onInputQueueCreated(activity *C.ANativeActivity, q *C.AInputQueue) {
	queue = q
}

//export onInputQueueDestroyed
func onInputQueueDestroyed(activity *C.ANativeActivity, queue *C.AInputQueue) {
	queue = nil
}

//export onContentRectChanged
func onContentRectChanged(activity *C.ANativeActivity, rect *C.ARect) {
}

//export onConfigurationChanged
func onConfigurationChanged(activity *C.ANativeActivity) {
}

//export onLowMemory
func onLowMemory(activity *C.ANativeActivity) {
}

func (Config) JavaVM() unsafe.Pointer {
	return unsafe.Pointer(C.current_vm)
}

// ClassFinder returns a C function pointer for finding a given class using
// the app class loader. (jclass) (*fn)(JNIEnv*, const char*).
func (Config) ClassFinder() unsafe.Pointer {
	return unsafe.Pointer(C.app_find_class)
}

func (Config) AndroidContext() unsafe.Pointer {
	return unsafe.Pointer(C.current_ctx)
}

var (
	windowDestroyed    = make(chan bool)
	windowCreated      = make(chan *C.ANativeWindow)
	windowRedrawNeeded = make(chan *C.ANativeWindow)
)

func openAsset(name string) (ReadSeekCloser, error) {
	cname := C.CString(name)
	defer C.free(unsafe.Pointer(cname))
	a := &asset{
		ptr:  C.AAssetManager_open(C.asset_manager, cname, C.AASSET_MODE_UNKNOWN),
		name: name,
	}
	if a.ptr == nil {
		return nil, a.errorf("open", "bad asset")
	}
	return a, nil
}

type asset struct {
	ptr  *C.AAsset
	name string
}

func (a *asset) errorf(op string, format string, v ...interface{}) error {
	return &os.PathError{
		Op:   op,
		Path: a.name,
		Err:  fmt.Errorf(format, v...),
	}
}

func (a *asset) Read(p []byte) (n int, err error) {
	n = int(C.AAsset_read(a.ptr, unsafe.Pointer(&p[0]), C.size_t(len(p))))
	if n == 0 && len(p) > 0 {
		return 0, io.EOF
	}
	if n < 0 {
		return 0, a.errorf("read", "negative bytes: %d", n)
	}
	return n, nil
}

func (a *asset) Seek(offset int64, whence int) (int64, error) {
	// TODO(crawshaw): use AAsset_seek64 if it is available.
	off := C.AAsset_seek(a.ptr, C.off_t(offset), C.int(whence))
	if off == -1 {
		return 0, a.errorf("seek", "bad result for offset=%d, whence=%d", offset, whence)
	}
	return int64(off), nil
}

func (a *asset) Close() error {
	C.AAsset_close(a.ptr)
	return nil
}

// notifyInitDone informs Java that the program is initialized.
// A NativeActivity will not create a window until this is called.
func run(callbacks []Callbacks) {
	// We want to keep the event loop on a consistent OS thread.
	runtime.LockOSThread()

	ctag := C.CString("Go")
	cstr := C.CString("app.Run")
	C.__android_log_write(C.ANDROID_LOG_INFO, ctag, cstr)
	C.free(unsafe.Pointer(ctag))
	C.free(unsafe.Pointer(cstr))

	close(mainCalled)
	if C.current_native_activity == nil {
		stateStart(callbacks)
		// TODO: stateStop under some conditions.
		select {}
	} else {
		for w := range windowCreated {
			windowDraw(callbacks, w, queue)
		}
	}
}
