// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package mgr

import (
	"code.google.com/p/winsvc/svc"
	"code.google.com/p/winsvc/winapi"
	"syscall"
)

// TODO(brainman): use EnumDependentServices to enumerate dependent services

// TODO(brainman): use EnumServicesStatus to enumerates services
//                 in the specified service control manager database

// Service is used to access Windows service.
type Service struct {
	Name   string
	Handle syscall.Handle
}

// Delete marks service s for deletion from the service control manager database.
func (s *Service) Delete() error {
	return winapi.DeleteService(s.Handle)
}

// Close relinquish access to service s.
func (s *Service) Close() error {
	return winapi.CloseServiceHandle(s.Handle)
}

// Start starts service s.
func (s *Service) Start(args []string) error {
	var p **uint16
	if len(args) > 0 {
		vs := make([]*uint16, len(args))
		for i, _ := range vs {
			vs[i] = syscall.StringToUTF16Ptr(args[i])
		}
		p = &vs[0]
	}
	return winapi.StartService(s.Handle, uint32(len(args)), p)
}

// Control sends state change request c to servce s.
func (s *Service) Control(c svc.Cmd) (svc.Status, error) {
	var t winapi.SERVICE_STATUS
	err := winapi.ControlService(s.Handle, uint32(c), &t)
	if err != nil {
		return svc.Status{}, err
	}
	return svc.Status{
		State:   svc.State(t.CurrentState),
		Accepts: svc.Accepted(t.ControlsAccepted),
	}, nil
}

// Query returns current status of service s.
func (s *Service) Query() (svc.Status, error) {
	var t winapi.SERVICE_STATUS
	err := winapi.QueryServiceStatus(s.Handle, &t)
	if err != nil {
		return svc.Status{}, err
	}
	return svc.Status{
		State:   svc.State(t.CurrentState),
		Accepts: svc.Accepted(t.ControlsAccepted),
	}, nil
}
