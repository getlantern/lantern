// Copyright 2015 Igor Dolzhikov. All rights reserved.
// Use of this source code is governed by
// license that can be found in the LICENSE file.

// Package daemon windows version
package daemon

import (
	"errors"
)

// windowsRecord - standard record (struct) for windows version of daemon package
type windowsRecord struct {
	name        string
	description string
}

func newDaemon(name, description string) (Daemon, error) {

	return &windowsRecord{name, description}, nil
}

// Install the service
func (windows *windowsRecord) Install() (string, error) {
	installAction := "Install " + windows.description + ":"

	return installAction + failed, errors.New("windows daemon is not supported")
}

// Remove the service
func (windows *windowsRecord) Remove() (string, error) {
	removeAction := "Removing " + windows.description + ":"

	return removeAction + failed, errors.New("windows daemon is not supported")
}

// Start the service
func (windows *windowsRecord) Start() (string, error) {
	startAction := "Starting " + windows.description + ":"

	return startAction + failed, errors.New("windows daemon is not supported")
}

// Stop the service
func (windows *windowsRecord) Stop() (string, error) {
	stopAction := "Stopping " + windows.description + ":"

	return stopAction + failed, errors.New("windows daemon is not supported")
}

// Status - Get service status
func (windows *windowsRecord) Status() (string, error) {

	return "Status could not defined", errors.New("windows daemon is not supported")
}
