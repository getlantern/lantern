// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

// Package eventlog implements access to Windows event log.
//
package eventlog

import (
	"code.google.com/p/winsvc/winapi"
	"errors"
	"syscall"
)

// Log provides access to system log.
type Log struct {
	Handle syscall.Handle
}

// Open retrieves a handle to the specified event log.
func Open(source string) (*Log, error) {
	return OpenRemote("", source)
}

// OpenRemote does the same as Open, but on different computer host.
func OpenRemote(host, source string) (*Log, error) {
	if source == "" {
		return nil, errors.New("Specify event log source")
	}
	var s *uint16
	if host != "" {
		s = syscall.StringToUTF16Ptr(host)
	}
	h, err := winapi.RegisterEventSource(s, syscall.StringToUTF16Ptr(source))
	if err != nil {
		return nil, err
	}
	return &Log{Handle: h}, nil
}

// Close closes event log l.
func (l *Log) Close() error {
	return winapi.DeregisterEventSource(l.Handle)
}

func (l *Log) report(etype uint16, eid uint32, msg string) error {
	ss := []*uint16{syscall.StringToUTF16Ptr(msg)}
	return winapi.ReportEvent(l.Handle, etype, 0, eid, 0, 1, 0, &ss[0], nil)
}

// Info writes an information event msg with event id eid to the end of event log l.
// eid must be between 1 and 1000 if using EventCreate.exe as event message file.
func (l *Log) Info(eid uint32, msg string) error {
	return l.report(winapi.EVENTLOG_INFORMATION_TYPE, eid, msg)
}

// Warning writes an warning event msg with event id eid to the end of event log l.
// eid must be between 1 and 1000 if using EventCreate.exe as event message file.
func (l *Log) Warning(eid uint32, msg string) error {
	return l.report(winapi.EVENTLOG_WARNING_TYPE, eid, msg)
}

// Error writes an error event msg with event id eid to the end of event log l.
// eid must be between 1 and 1000 if using EventCreate.exe as event message file.
func (l *Log) Error(eid uint32, msg string) error {
	return l.report(winapi.EVENTLOG_ERROR_TYPE, eid, msg)
}
