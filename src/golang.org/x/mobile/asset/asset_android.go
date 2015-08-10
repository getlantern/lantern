// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package asset

/*
#cgo LDFLAGS: -llog -landroid
#include <android/log.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <jni.h>
#include <stdlib.h>

#define LOG_FATAL(...) __android_log_print(ANDROID_LOG_FATAL, "Go/asset", __VA_ARGS__)

// asset_manager is the asset manager of the app.
AAssetManager* asset_manager;

void asset_manager_init(void* java_vm, void* ctx) {
	JavaVM* vm = (JavaVM*)(java_vm);
	JNIEnv* env;
	int err;
	int attached = 0;

	err = (*vm)->GetEnv(vm, (void**)&env, JNI_VERSION_1_6);
	if (err != JNI_OK) {
		if (err == JNI_EDETACHED) {
			if ((*vm)->AttachCurrentThread(vm, &env, 0) != 0) {
				LOG_FATAL("cannot attach JVM");
			}
			attached = 1;
		} else {
			LOG_FATAL("GetEnv unexpected error: %d", err);
		}
	}

	// Equivalent to:
	//	assetManager = ctx.getResources().getAssets();
	jclass ctx_clazz = (*env)->FindClass(env, "android/content/Context");
	jmethodID getres_id = (*env)->GetMethodID(env, ctx_clazz, "getResources", "()Landroid/content/res/Resources;");
	jobject res = (*env)->CallObjectMethod(env, ctx, getres_id);
	jclass res_clazz = (*env)->FindClass(env, "android/content/res/Resources");
	jmethodID getam_id = (*env)->GetMethodID(env, res_clazz, "getAssets", "()Landroid/content/res/AssetManager;");
	jobject am = (*env)->CallObjectMethod(env, res, getam_id);

	// Pin the AssetManager and load an AAssetManager from it.
	am = (*env)->NewGlobalRef(env, am);
	asset_manager = AAssetManager_fromJava(env, am);

	if (attached) {
		(*vm)->DetachCurrentThread(vm);
	}
}
*/
import "C"
import (
	"fmt"
	"io"
	"os"
	"sync"
	"unsafe"

	"golang.org/x/mobile/internal/mobileinit"
)

var assetOnce sync.Once

func assetInit() {
	ctx := mobileinit.Context{}
	C.asset_manager_init(ctx.JavaVM(), ctx.AndroidContext())
}

func openAsset(name string) (File, error) {
	assetOnce.Do(assetInit)
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
