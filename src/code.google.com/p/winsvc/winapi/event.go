// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package winapi

//sys	CreateEvent(eventAttrs *syscall.SecurityAttributes, manualReset uint32, initialState uint32, name *uint16) (handle syscall.Handle, err error) = kernel32.CreateEventW
//sys	SetEvent(event syscall.Handle) (err error) = kernel32.SetEvent
