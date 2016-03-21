// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package objc

import (
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Use the Xcode XCTestCase framework to run the SeqTest.m tests and the SeqBench.m benchmarks.
//
// SeqTest.m runs in the xcodetest project as normal unit test (logic test in Xcode lingo).
// Unit tests execute faster but cannot run on a real device. That is why SeqBench.m runs as
// a UI unit test through the xcodebench project.
//
// Both xcodetest and xcodebench were constructed in Xcode 7 by:
//
// - Creating a new project through Xcode. Choose to include either unit tests or UI tests as
//   needed.
// - Add SeqTest.m or SeqBench.m to the right unit test target.
// - Xcode schemes are per-user by default. The shared scheme is created by selecting
//   Project => Schemes => Manage Schemes from the Xcode menu and selecting "Shared".
// - Remove files not needed for xcodebuild (determined empirically). In particular, the empty
//   tests Xcode creates can be removed and the unused user scheme.

var destination = flag.String("device", "platform=iOS Simulator,name=iPhone 6s Plus", "Specify the -destination flag to xcodebuild")

// TestObjcSeqTest runs ObjC test SeqTest.m.
// This requires the xcode command lines tools.
func TestObjcSeqTest(t *testing.T) {
	runTest(t, []string{
		"golang.org/x/mobile/bind/testpkg",
		"golang.org/x/mobile/bind/testpkg/secondpkg",
		"golang.org/x/mobile/bind/testpkg/simplepkg",
	}, "xcodetest", "SeqTest.m", false)
}

// TestObjcSeqBench runs ObjC test SeqBench.m.
// This requires the xcode command lines tools.
func TestObjcSeqBench(t *testing.T) {
	runTest(t, []string{"golang.org/x/mobile/bind/benchmark"}, "xcodebench", "SeqBench.m", true)
}

func runTest(t *testing.T, pkgNames []string, project, testfile string, dumpOutput bool) {
	if _, err := run("which xcodebuild"); err != nil {
		t.Skip("command xcodebuild not found, skipping")
	}
	if _, err := run("which gomobile"); err != nil {
		t.Log("go install gomobile")
		if _, err := run("go install golang.org/x/mobile/cmd/gomobile"); err != nil {
			t.Fatalf("gomobile install failed: %v", err)
		}
		t.Log("gomobile init")
		start := time.Now()
		if _, err := run("gomobile init"); err != nil {
			t.Fatalf("gomobile init failed: %v", err)
		}
		t.Logf("gomobile init took %v", time.Since(start))
	}

	cwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed pwd: %v", err)
	}
	tmpdir, err := ioutil.TempDir("", "bind-objc-seq-test-")
	if err != nil {
		t.Fatalf("failed to prepare temp dir: %v", err)
	}
	defer os.RemoveAll(tmpdir)
	t.Logf("tmpdir = %s", tmpdir)

	if buf, err := exec.Command("cp", "-a", project, tmpdir).CombinedOutput(); err != nil {
		t.Logf("%s", buf)
		t.Fatalf("failed to copy %s to tmp dir: %v", project, err)
	}

	if err := cp(filepath.Join(tmpdir, testfile), testfile); err != nil {
		t.Fatalf("failed to copy %s: %v", testfile, err)
	}

	if err := os.Chdir(filepath.Join(tmpdir, project)); err != nil {
		t.Fatalf("failed chdir: %v", err)
	}
	defer os.Chdir(cwd)

	buf, err := run("gomobile bind -target=ios " + strings.Join(pkgNames, " "))
	if err != nil {
		t.Logf("%s", buf)
		t.Fatalf("failed to run gomobile bind: %v", err)
	}

	cmd := exec.Command("xcodebuild", "test", "-scheme", project, "-destination", *destination)
	buf, err = cmd.CombinedOutput()
	if err != nil {
		t.Logf("%s", buf)
		t.Errorf("failed to run xcodebuild: %v", err)
	}
	if dumpOutput {
		t.Logf("%s", buf)
	}
}

func run(cmd string) ([]byte, error) {
	c := strings.Split(cmd, " ")
	return exec.Command(c[0], c[1:]...).CombinedOutput()
}

func cp(dst, src string) error {
	r, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to read source: %v", err)
	}
	defer r.Close()
	w, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("failed to open destination: %v", err)
	}
	_, err = io.Copy(w, r)
	cerr := w.Close()
	if err != nil {
		return err
	}
	return cerr
}
