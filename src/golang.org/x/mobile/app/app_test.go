// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package app_test

import (
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"golang.org/x/mobile/app/internal/apptest"
)

// TestAndroidApp tests the lifecycle, event, and window semantics of a
// simple android app.
//
// Beyond testing the app package, the goal is to eventually have
// helper libraries that make tests like these easy to write. Hopefully
// having a user of such a fictional package will help illuminate the way.
func TestAndroidApp(t *testing.T) {
	if _, err := exec.Command("which", "adb").CombinedOutput(); err != nil {
		t.Skip("command adb not found, skipping")
	}

	run(t, "gomobile", "version")

	origWD, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}

	tmpdir, err := ioutil.TempDir("", "app-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpdir)

	if err := os.Chdir(tmpdir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origWD)

	run(t, "gomobile", "install", "golang.org/x/mobile/app/internal/testapp")

	ln, err := net.Listen("tcp4", "localhost:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	localaddr := fmt.Sprintf("tcp:%d", ln.Addr().(*net.TCPAddr).Port)
	t.Logf("local address: %s", localaddr)

	exec.Command("adb", "reverse", "--remove", "tcp:"+apptest.Port).Run() // ignore failure
	run(t, "adb", "reverse", "tcp:"+apptest.Port, localaddr)

	const (
		KeycodePower  = "26"
		KeycodeUnlock = "82"
	)

	run(t, "adb", "shell", "input", "keyevent", KeycodePower)
	run(t, "adb", "shell", "input", "keyevent", KeycodeUnlock)

	// start testapp
	run(t,
		"adb", "shell", "am", "start", "-n",
		"org.golang.testapp/org.golang.app.GoNativeActivity",
	)

	var conn net.Conn
	connDone := make(chan struct{})
	go func() {
		conn, err = ln.Accept()
		connDone <- struct{}{}
	}()

	select {
	case <-time.After(5 * time.Second):
		t.Fatal("timeout waiting for testapp to dial host")
	case <-connDone:
		if err != nil {
			t.Fatalf("ln.Accept: %v", err)
		}
	}
	defer conn.Close()
	comm := &apptest.Comm{
		Conn:   conn,
		Fatalf: t.Fatalf,
		Printf: t.Logf,
	}

	var PixelsPerPt float32

	comm.Recv("hello_from_testapp")
	comm.Send("hello_from_host")
	comm.Recv("lifecycle_visible")
	comm.Recv("config", &PixelsPerPt)
	if PixelsPerPt < 0.1 {
		t.Fatalf("bad PixelsPerPt: %f", PixelsPerPt)
	}
	comm.Recv("paint")

	var x, y int
	var ty string

	tap(t, 50, 60)
	comm.Recv("touch", &ty, &x, &y)
	if ty != "begin" || x != 50 || y != 60 {
		t.Errorf("want touch begin(50, 60), got %s(%d,%d)", ty, x, y)
	}
	comm.Recv("touch", &ty, &x, &y)
	if ty != "end" || x != 50 || y != 60 {
		t.Errorf("want touch end(50, 60), got %s(%d,%d)", ty, x, y)
	}

	// TODO: screenshot of gl.Clear to test painting
	// TODO: lifecycle testing (NOTE: adb shell input keyevent 4 is the back button)
	// TODO: orientation testing
}

func tap(t *testing.T, x, y int) {
	run(t, "adb", "shell", "input", "tap", fmt.Sprintf("%d", x), fmt.Sprintf("%d", y))
}

func run(t *testing.T, cmdName string, arg ...string) {
	cmd := exec.Command(cmdName, arg...)
	t.Log(strings.Join(cmd.Args, " "))
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s %v: %s", strings.Join(cmd.Args, " "), err, out)
	}
}
