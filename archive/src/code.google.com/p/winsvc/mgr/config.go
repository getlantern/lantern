// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package mgr

import (
	"code.google.com/p/winsvc/winapi"
	"syscall"
	"unicode/utf16"
	"unsafe"
)

const (
	// Service start types
	StartManual    = winapi.SERVICE_DEMAND_START // the service must be started manually
	StartAutomatic = winapi.SERVICE_AUTO_START   // the service will start by itself whenever the computer reboots
	StartDisabled  = winapi.SERVICE_DISABLED     // the service cannot be started

	// The severity of the error, and action taken,
	// if this service fails to start.
	ErrorCritical = winapi.SERVICE_ERROR_CRITICAL
	ErrorIgnore   = winapi.SERVICE_ERROR_IGNORE
	ErrorNormal   = winapi.SERVICE_ERROR_NORMAL
	ErrorSevere   = winapi.SERVICE_ERROR_SEVERE
)

// TODO: Password is not returned by winapi.QueryServiceConfig, maybe I should do something about it

type Config struct {
	ServiceType      uint32
	StartType        uint32
	ErrorControl     uint32
	BinaryPathName   string
	LoadOrderGroup   string
	TagId            uint32
	Dependencies     []string
	ServiceStartName string // name of the account under which the service should run
	DisplayName      string
	Password         string
	Description      string
}

func toString(p *uint16) string {
	if p == nil {
		return ""
	}
	return syscall.UTF16ToString((*[4096]uint16)(unsafe.Pointer(p))[:])
}

func toStringSlice(ps *uint16) []string {
	if ps == nil {
		return nil
	}
	r := make([]string, 0)
	for from, i, p := 0, 0, (*[1 << 24]uint16)(unsafe.Pointer(ps)); true; i++ {
		if p[i] == 0 {
			// empty string marks the end
			if i <= from {
				break
			}
			r = append(r, string(utf16.Decode(p[from:i])))
			from = i + 1
		}
	}
	return r
}

func (s *Service) Config() (Config, error) {
	b := make([]byte, 1024)
	p := (*winapi.QUERY_SERVICE_CONFIG)(unsafe.Pointer(&b[0]))
	var l uint32
	err := winapi.QueryServiceConfig(s.Handle, p, uint32(len(b)), &l)
	if err != nil {
		if err.(syscall.Errno) != syscall.ERROR_INSUFFICIENT_BUFFER {
			return Config{}, err
		}
		b = make([]byte, l)
		p = (*winapi.QUERY_SERVICE_CONFIG)(unsafe.Pointer(&b[0]))
		err = winapi.QueryServiceConfig(s.Handle, p, l, &l)
		if err != nil {
			return Config{}, err
		}
	}
	b = make([]byte, 1024)
	err = winapi.QueryServiceConfig2(s.Handle,
		winapi.SERVICE_CONFIG_DESCRIPTION, &b[0], uint32(len(b)), &l)
	if err != nil {
		if err.(syscall.Errno) != syscall.ERROR_INSUFFICIENT_BUFFER {
			return Config{}, err
		}
		b = make([]byte, l)
		err = winapi.QueryServiceConfig2(s.Handle,
			winapi.SERVICE_CONFIG_DESCRIPTION, &b[0], uint32(len(b)), &l)
		if err != nil {
			return Config{}, err
		}
	}
	p2 := (*winapi.SERVICE_DESCRIPTION)(unsafe.Pointer(&b[0]))
	return Config{
		ServiceType:      p.ServiceType,
		StartType:        p.StartType,
		ErrorControl:     p.ErrorControl,
		BinaryPathName:   toString(p.BinaryPathName),
		LoadOrderGroup:   toString(p.LoadOrderGroup),
		TagId:            p.TagId,
		Dependencies:     toStringSlice(p.Dependencies),
		ServiceStartName: toString(p.ServiceStartName),
		DisplayName:      toString(p.DisplayName),
		Description:      toString(p2.Description),
	}, nil
}

func updateDescription(handle syscall.Handle, desc string) error {
	d := winapi.SERVICE_DESCRIPTION{toPtr(desc)}
	err := winapi.ChangeServiceConfig2(handle,
		winapi.SERVICE_CONFIG_DESCRIPTION, (*byte)(unsafe.Pointer(&d)))
	if err != nil {
		return err
	}
	return nil
}

func (s *Service) UpdateConfig(c Config) error {
	err := winapi.ChangeServiceConfig(s.Handle, c.ServiceType, c.StartType,
		c.ErrorControl, toPtr(c.BinaryPathName), toPtr(c.LoadOrderGroup),
		nil, toStringBlock(c.Dependencies), toPtr(c.ServiceStartName),
		toPtr(c.Password), toPtr(c.DisplayName))
	if err != nil {
		return err
	}
	err = updateDescription(s.Handle, c.Description)
	if err != nil {
		return err
	}
	return nil
}
