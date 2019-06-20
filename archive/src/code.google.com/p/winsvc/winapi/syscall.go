// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package winapi

import "syscall"

const (
	STANDARD_RIGHTS_REQUIRED = 0xf0000

	ERROR_SERVICE_SPECIFIC_ERROR syscall.Errno = 1066
)

//sys	GetCurrentThreadId() (id uint32)
