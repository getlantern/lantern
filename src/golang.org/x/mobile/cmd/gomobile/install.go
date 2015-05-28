// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"os"
	"os/exec"
	"path/filepath"
)

var cmdInstall = &command{
	run:   runInstall,
	Name:  "install",
	Usage: "[package]",
	Short: "compile android APK and iOS app and install on device",
	Long: `
Install compiles and installs the app named by the import path on the
attached mobile device.

This command requires the 'adb' tool on the PATH.

See the build command help for common flags and common behavior.
`,
}

func runInstall(cmd *command) error {
	if err := runBuild(cmd); err != nil {
		return err
	}
	install := exec.Command(
		`adb`,
		`install`,
		`-r`,
		filepath.Base(pkg.Dir)+`.apk`,
	)
	if buildV {
		install.Stdout = os.Stdout
		install.Stderr = os.Stderr
	}
	return install.Run()
}
