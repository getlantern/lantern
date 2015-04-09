// Copyright 2015 Igor Dolzhikov. All rights reserved.
// Use of this source code is governed by
// license that can be found in the LICENSE file.

// Package daemon linux version
package daemon

import (
	"os"
)

// Get the daemon properly
func newDaemon(name, description string) (Daemon, error) {
	if _, err := os.Stat("/run/systemd/system"); err == nil {
		return &systemDRecord{name, description}, nil
	}
	return &systemVRecord{name, description}, nil
}

// Get executable path
func execPath() (string, error) {
	return os.Readlink("/proc/self/exe")
}
