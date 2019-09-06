// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package winapi

const (
	REG_OPTION_NON_VOLATILE = 0

	REG_CREATED_NEW_KEY     = 1
	REG_OPENED_EXISTING_KEY = 2
)

//sys	RegCreateKeyEx(key syscall.Handle, subkey *uint16, reserved uint32, class *uint16, options uint32, desired uint32, sa *syscall.SecurityAttributes, result *syscall.Handle, disposition *uint32) (regerrno error) = advapi32.RegCreateKeyExW
//sys	RegDeleteKey(key syscall.Handle, subkey *uint16) (regerrno error) = advapi32.RegDeleteKeyW
//sys	RegSetValueEx(key syscall.Handle, valueName *uint16, reserved uint32, vtype uint32, buf *byte, bufsize uint32) (regerrno error) = advapi32.RegSetValueExW
