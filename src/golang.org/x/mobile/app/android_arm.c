// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android,arm

#include <android/log.h>
#include <stdint.h>
#include <string.h>
#include "_cgo_export.h"

#define AT_PLATFORM  15
#define AT_HWCAP     16
#define HWCAP_VFP    (1 << 6)
#define HWCAP_VFPv3  (1 << 13)

void build_auxv(uint32_t *auxv, size_t len) {
	// Minimum auxv required by runtime/os_linux_arm.go.
	int i;
	if (len < 5) {
		__android_log_print(ANDROID_LOG_FATAL, "Go", "auxv len %d too small", len);
	}
	auxv[0] = AT_PLATFORM;
	*(char**)&auxv[1] = strdup("v7l");

	auxv[2] = AT_HWCAP;
	auxv[3] = HWCAP_VFP | HWCAP_VFPv3;
	for (i = 4; i < len; i++) {
		auxv[i] = 0;
	}
}
