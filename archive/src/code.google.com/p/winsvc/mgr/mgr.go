// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

// Package mgr can be used to manage Windows service programs.
// It can be used to install and remove them. It can also start,
// stop, pause and so on. It can query current service state.
// It can query service config parameters and change them.
//
package mgr

import (
	"code.google.com/p/winsvc/winapi"
	"syscall"
	"unicode/utf16"
)

// Mgr is used to manage Windows service.
type Mgr struct {
	Handle syscall.Handle
}

// Connect establishes a connection to the service control manager.
func Connect() (*Mgr, error) {
	return ConnectRemote("")
}

// ConnectRemote establishes a connection to the
// service control manager on computer named host.
func ConnectRemote(host string) (*Mgr, error) {
	var s *uint16
	if host != "" {
		s = syscall.StringToUTF16Ptr(host)
	}
	h, err := winapi.OpenSCManager(s, nil, winapi.SC_MANAGER_ALL_ACCESS)
	if err != nil {
		return nil, err
	}
	return &Mgr{Handle: h}, nil
}

// Disconnect closes connection m to servise control manager.
func (m *Mgr) Disconnect() error {
	return winapi.CloseServiceHandle(m.Handle)
}

func toPtr(s string) *uint16 {
	if len(s) == 0 {
		return nil
	}
	return syscall.StringToUTF16Ptr(s)
}

// toStringBlock terminates strings in ss with 0, and then
// concatenates them together. It also adds extra 0 at the end.
func toStringBlock(ss []string) *uint16 {
	if len(ss) == 0 {
		return nil
	}
	t := ""
	for _, s := range ss {
		if s != "" {
			t += s + "\x00"
		}
	}
	if t == "" {
		return nil
	}
	t += "\x00"
	return &utf16.Encode([]rune(t))[0]
}

// CreateService installs new service name on the system.
// The service will be executed by running exepath binary,
// while service settings are specified in config c.
func (m *Mgr) CreateService(name, exepath string, c Config) (*Service, error) {
	if c.StartType == 0 {
		c.StartType = StartManual
	}
	if c.ErrorControl == 0 {
		c.ErrorControl = ErrorNormal
	}
	c.BinaryPathName = exepath // execpath is important, do not rely on BinaryPathName field to be set
	h, err := winapi.CreateService(m.Handle, toPtr(name), toPtr(c.DisplayName),
		winapi.SERVICE_ALL_ACCESS, winapi.SERVICE_WIN32_OWN_PROCESS,
		c.StartType, c.ErrorControl, toPtr(exepath), toPtr(c.LoadOrderGroup),
		nil, toStringBlock(c.Dependencies), toPtr(c.ServiceStartName), toPtr(c.Password))
	if err != nil {
		return nil, err
	}
	if c.Description != "" {
		err = updateDescription(h, c.Description)
		if err != nil {
			return nil, err
		}
	}
	return &Service{Name: name, Handle: h}, nil
}

// OpenService retrievs access to service name, so it can
// be interrogated and controlled.
func (m *Mgr) OpenService(name string) (*Service, error) {
	h, err := winapi.OpenService(m.Handle, syscall.StringToUTF16Ptr(name), winapi.SERVICE_ALL_ACCESS)
	if err != nil {
		return nil, err
	}
	return &Service{Name: name, Handle: h}, nil
}
