// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

// Package debug provides facilities to execute svc.Handler on console.
//
package debug

import (
	"code.google.com/p/winsvc/svc"
	"os"
	"os/signal"
	"syscall"
)

// Run executes service named name by calling appropriate handler function.
// The process is running on console, unlike real service. Use Ctrl+C to
// send "Stop" command to your service.
func Run(name string, handler svc.Handler) error {
	cmds := make(chan svc.ChangeRequest)
	changes := make(chan svc.Status)

	sig := make(chan os.Signal)
	signal.Notify(sig)

	go func() {
		status := svc.Status{State: svc.Stopped}
		for {
			select {
			case <-sig:
				cmds <- svc.ChangeRequest{svc.Stop, status}
			case status = <-changes:
			}
		}
	}()

	_, errno := handler.Execute([]string{name}, cmds, changes)
	if errno != 0 {
		return syscall.Errno(errno)
	}
	return nil
}
