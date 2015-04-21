// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package winapi

const (
	EVENTLOG_ERROR_TYPE = 1 << iota
	EVENTLOG_WARNING_TYPE
	EVENTLOG_INFORMATION_TYPE
	EVENTLOG_AUDIT_SUCCESS
	EVENTLOG_AUDIT_FAILURE
	EVENTLOG_SUCCESS = 0
)

//sys	RegisterEventSource(uncServerName *uint16, sourceName *uint16) (handle syscall.Handle, err error) [failretval==0] = advapi32.RegisterEventSourceW
//sys	DeregisterEventSource(handle syscall.Handle) (err error) = advapi32.DeregisterEventSource
//sys	ReportEvent(log syscall.Handle, etype uint16, category uint16, eventId uint32, usrSId uintptr, numStrings uint16, dataSize uint32, strings **uint16, rawData *byte) (err error) = advapi32.ReportEventW
