// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package asset

/*
#cgo LDFLAGS: -landroid
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <jni.h>
#include <stdlib.h>

// asset_manager is the asset manager of the app.
AAssetManager* asset_manager;

void asset_manager_init(uintptr_t java_vm, uintptr_t jni_env, jobject ctx) {
	JavaVM* vm = (JavaVM*)java_vm;
	JNIEnv* env = (JNIEnv*)jni_env;

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
}
*/
import "C"
import (
	"fmt"
	"io"
	"log"
	"os"
	"sync"
	"unsafe"

	"golang.org/x/mobile/internal/mobileinit"
)

var assetOnce sync.Once

func assetInit() {
	err := mobileinit.RunOnJVM(func(vm, env, ctx uintptr) error {
		C.asset_manager_init(C.uintptr_t(vm), C.uintptr_t(env), C.jobject(ctx))
		return nil
	})
	if err != nil {
		log.Fatalf("asset: %v", err)
	}
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
