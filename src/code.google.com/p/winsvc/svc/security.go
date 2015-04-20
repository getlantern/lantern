// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package svc

import (
	"code.google.com/p/winsvc/winapi"
	"syscall"
	"unsafe"
)

// TODO(brainman): move some of that code to syscall/security.go

// getInfo retrieves a specified type of information about an access token.
func getInfo(t syscall.Token, class uint32, initSize int) (unsafe.Pointer, error) {
	b := make([]byte, initSize)
	var n uint32
	e := syscall.GetTokenInformation(t, class, &b[0], uint32(len(b)), &n)
	if e != nil {
		if e != syscall.ERROR_INSUFFICIENT_BUFFER {
			return nil, e
		}
		// make receive buffers of requested size and try again
		b = make([]byte, n)
		e = syscall.GetTokenInformation(t, class, &b[0], uint32(len(b)), &n)
		if e != nil {
			return nil, e
		}
	}
	return unsafe.Pointer(&b[0]), nil
}

// getTokenUser retrieves access token t user account information.
func getTokenGroups(t syscall.Token) (*winapi.Tokengroups, error) {
	i, e := getInfo(t, syscall.TokenGroups, 50)
	if e != nil {
		return nil, e
	}
	return (*winapi.Tokengroups)(i), nil
}

func allocSid(subAuth0 uint32) (*syscall.SID, error) {
	var sid *syscall.SID
	err := winapi.AllocateAndInitializeSid(&winapi.SECURITY_NT_AUTHORITY,
		1, subAuth0, 0, 0, 0, 0, 0, 0, 0, &sid)
	if err != nil {
		return nil, err
	}
	return sid, nil
}

// IsAnInteractiveSession determines if calling process is running interactively.
// It queries the process token for membership in the Interactive group.
// http://stackoverflow.com/questions/2668851/how-do-i-detect-that-my-application-is-running-as-service-or-in-an-interactive-s
func IsAnInteractiveSession() (bool, error) {
	interSid, err := allocSid(winapi.SECURITY_INTERACTIVE_RID)
	if err != nil {
		return false, err
	}
	defer winapi.FreeSid(interSid)

	serviceSid, err := allocSid(winapi.SECURITY_SERVICE_RID)
	if err != nil {
		return false, err
	}
	defer winapi.FreeSid(serviceSid)

	t, err := syscall.OpenCurrentProcessToken()
	if err != nil {
		return false, err
	}
	defer t.Close()

	gs, err := getTokenGroups(t)
	if err != nil {
		return false, err
	}
	p := unsafe.Pointer(&gs.Groups[0])
	groups := (*[2 << 20]syscall.SIDAndAttributes)(p)[:gs.GroupCount]
	for _, g := range groups {
		if winapi.EqualSid(g.Sid, interSid) {
			return true, nil
		}
		if winapi.EqualSid(g.Sid, serviceSid) {
			return false, nil
		}
	}
	return false, nil
}

// IsAnIinteractiveSession is a misspelled version of IsAnInteractiveSession.
// Do not use. It is kept here so we do not break existing code.
func IsAnIinteractiveSession() (bool, error) {
	return IsAnInteractiveSession()
}
