// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"os/exec"
	"path/filepath"
)

var cmdInstall = &command{
	run:   runInstall,
	Name:  "install",
	Usage: "[-target android] [build flags] [package]",
	Short: "compile android APK and install on device",
	Long: `
Install compiles and installs the app named by the import path on the
attached mobile device.

Only -target android is supported. The 'adb' tool must be on the PATH.

The build flags -a, -i, -n, -x, -gcflags, -ldflags, -tags, and -work are
shared with the build command.
For documentation, see 'go help build'.
`,
}

func runInstall(cmd *command) error {
	if buildTarget != "android" {
		return fmt.Errorf("install is not supported for -target=%s", buildTarget)
	}
	if err := runBuild(cmd); err != nil {
		return err
	}
	return runCmd(exec.Command(
		`adb`,
		`install`,
		`-r`,
		filepath.Base(pkg.Dir)+`.apk`,
	))
}
