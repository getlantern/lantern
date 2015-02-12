// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build ignore

// This program can be used as go_android_GOARCH_exec by the Go tool.
// It executes binaries on an android device using adb.
// This program is supposed to be called by
// golang.org/x/mobile/build/androidtest.bash that arranges to copy
// the tested repository source tree to the android device and invokes
// go test. This program depends on PKG and DEVICEDIR environment variables
// to identify the tested repository (e.g. golang.org/x/mobile) and
// to find the source directory in the android device. The androidtest.bash
// script is responsible for setting the environment variables.
package main

// This is adopted from golang.org/x/go/misc/android/go_android_exec.go.

import (
	"bytes"
	"fmt"
	"go/build"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"
)

func run(args ...string) string {
	buf := new(bytes.Buffer)
	cmd := exec.Command("adb", args...)
	cmd.Stdout = io.MultiWriter(os.Stdout, buf)
	cmd.Stderr = os.Stderr
	log.Printf("adb %s", strings.Join(args, " "))
	err := cmd.Run()
	if err != nil {
		log.Fatalf("adb %s: %v", strings.Join(args, " "), err)
	}
	return buf.String()
}

func rel(cwd, pkg string) (string, error) {
	paths := build.Default.GOPATH
	for _, p := range filepath.SplitList(paths) {
		r, err := filepath.Rel(filepath.Join(p, "src", pkg), cwd)
		if err == nil {
			return r, nil
		}
	}
	return "", fmt.Errorf("%q is not under GOPATH(%q)", cwd, paths)
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("go_android_exec: ")

	deviceRoot := "/data/local/tmp/"
	if v := os.Getenv("DEVICEDIR"); v != "" {
		deviceRoot = v
	}

	pkg := "golang.org/x/mobile"
	if v := os.Getenv("PKG"); v != "" {
		pkg = v
	}

	// Binary names can conflict.
	// E.g. template.test from the {html,text}/template packages.
	binName := filepath.Base(os.Args[1])
	deviceBin := fmt.Sprintf("%s/%s-%d", deviceRoot, binName, os.Getpid())

	// The push of the binary happens in parallel with other tests.
	// Unfortunately, a simultaneous call to adb shell hold open
	// file descriptors, so it is necessary to push then move to
	// avoid a "text file busy" error on execution.
	// https://code.google.com/p/android/issues/detail?id=65857
	run("push", "-p", os.Args[1], deviceBin+"-tmp")
	run("shell", "cp '"+deviceBin+"-tmp' '"+deviceBin+"'")
	run("shell", "rm '"+deviceBin+"-tmp'")

	cwd, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}

	subdir, err := rel(cwd, pkg)
	if err != nil {
		log.Fatal(err)
	}
	subdir = filepath.Join(deviceRoot, pkg, subdir)

	// The adb shell command will return an exit code of 0 regardless
	// of the command run. E.g.
	//	$ adb shell false
	//	$ echo $?
	//	0
	// https://code.google.com/p/android/issues/detail?id=3254
	// So we append the exitcode to the output and parse it from there.
	t := template.Must(template.New("cmd").Parse(
		`export TMPDIR={{.Root}}/tmp; \
		 mkdir -p "$TMPDIR"; \
		 cd "{{.SubDir}}"; \
		 {{.Bin}} {{.Args}}; \
		 echo -n {{.ExitStr}}$?`))

	var cmd bytes.Buffer
	const exitstr = "exitcode="
	if err := t.Execute(&cmd, struct {
		Root, SubDir, Bin, Args, ExitStr string
	}{
		Root:    deviceRoot,
		SubDir:  subdir,
		Bin:     deviceBin,
		Args:    strings.Join(os.Args[2:], " "),
		ExitStr: exitstr,
	}); err != nil {
		log.Panicf("template error: %v", err)
	}

	output := run("shell", cmd.String())
	output = output[strings.LastIndex(output, "\n")+1:]

	if !strings.HasPrefix(output, exitstr) {
		log.Fatalf("no exit code: %q", output)
	}
	code, err := strconv.Atoi(output[len(exitstr):])
	if err != nil {
		log.Fatalf("bad exit code: %v", err)
	}
	os.Exit(code)
}
