# Copyright 2014 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE    := basic
LOCAL_SRC_FILES := $(TARGET_ARCH_ABI)/libbasic.so

include $(PREBUILT_SHARED_LIBRARY)
