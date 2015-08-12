// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

var cmdVersion = &command{
	run:   runVersion,
	Name:  "version",
	Usage: "",
	Short: "print version",
	Long: `
Version prints versions of the gomobile binary and tools
`,
}

func runVersion(cmd *command) (err error) {
	// Check this binary matches the version in golang.org/x/mobile/cmd/gomobile
	// source code in GOPATH. If they don't match, currently there is no
	// way to reliably identify the revision number this binary was built
	// against.
	version := func() string {
		bin, err := exec.LookPath(os.Args[0])
		if err != nil {
			return ""
		}
		bindir := filepath.Dir(bin)
		cmd := exec.Command("go", "install", "-x", "-n", "golang.org/x/mobile/cmd/gomobile")
		cmd.Env = append(os.Environ(), "GOBIN="+bindir)
		out, err := cmd.CombinedOutput()
		if err != nil || len(out) != 0 {
			return ""
		}
		if rev, err := mobileRepoRevision(); err == nil {
			return rev
		}
		return ""
	}()
	if version == "" {
		fmt.Println("gomobile version unknown")
		return nil
	}

	// Supported platforms
	platforms := "android"
	if goos == "darwin" {
		platforms = "android,ios"
	}

	// ANDROID_HOME, sdk build tool version
	androidapi, _ := androidAPIPath()

	fmt.Printf("gomobile version %s (%s); androidSDK=%s\n", version, platforms, androidapi)
	return nil
}

func mobileRepoRevision() (rev string, err error) {
	b, err := exec.Command("go", "list", "-f", "{{.Dir}}", "golang.org/x/mobile/app").CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("mobile repo not found: %v", err)
	}

	repo := filepath.Dir(string(b))
	if err := os.Chdir(repo); err != nil {
		return "", fmt.Errorf("mobile repo %q not accessible: %v", repo, err)
	}
	revision, err := exec.Command("git", "log", "-n", "1", "--format=format: +%h %cd", "HEAD").CombinedOutput()
	if err != nil {
		return "", err
	}
	return string(bytes.Trim(revision, " \t\r\n")), nil
}
