// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build android,x86

#include <android/log.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "_cgo_export.h"

void build_auxv(uint32_t *xauxv, size_t xauxv_len) {
	char* auxv = (char*)xauxv;
	size_t auxv_len = xauxv_len*sizeof(uint32_t);

	// TODO(crawshaw): determine if we can read /proc/self/auxv on
	//                 x86 android release builds.
	int fd = open("/proc/self/auxv", O_RDONLY, 0);
	if (fd == -1) {
		__android_log_print(ANDROID_LOG_FATAL, "Go", "cannot open /proc/self/auxv: %s", strerror(errno));
	}
	int n = read(fd, &auxv, auxv_len);
	if (n < 0) {
		__android_log_print(ANDROID_LOG_FATAL, "Go", "error reading /proc/self/auxv: %s", strerror(errno));
	}
	if (n == auxv_len) { // auxv should be more than plenty.
		__android_log_print(ANDROID_LOG_FATAL, "Go", "/proc/self/auxv too big");
	}
	close(fd);

	for (; n < auxv_len; n++) {
		auxv[n] = 0;
	}
}
