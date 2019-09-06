// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package app_test

import (
	"fmt"
	"image"
	"image/color"
	_ "image/png"
	"io/ioutil"
	"net"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"golang.org/x/mobile/app/internal/apptest"
	"golang.org/x/mobile/event/size"
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
	devicesTxt, err := exec.Command("adb", "devices").CombinedOutput()
	if err != nil {
		t.Errorf("adb devices failed: %v: %v", err, devicesTxt)
	}
	deviceCount := 0
	for _, d := range strings.Split(strings.TrimSpace(string(devicesTxt)), "\n") {
		if strings.Contains(d, "List of devices") {
			continue
		}
		// TODO(crawshaw): I believe some unusable devices can appear in the
		// list with note on them, but I cannot reproduce this right now.
		deviceCount++
	}
	if deviceCount == 0 {
		t.Skip("no android devices attached")
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

	const (
		rotationPortrait  = "0"
		rotationLandscape = "1"
	)

	rotate := func(rotation string) {
		run(t, "adb", "shell", "content", "insert", "--uri", "content://settings/system", "--bind", "name:s:user_rotation", "--bind", "value:i:"+rotation)
	}

	// turn off automatic rotation and start in portrait
	run(t, "adb", "shell", "content", "insert", "--uri", "content://settings/system", "--bind", "name:s:accelerometer_rotation", "--bind", "value:i:0")
	rotate(rotationPortrait)

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

	var pixelsPerPt float32
	var orientation size.Orientation

	comm.Recv("hello_from_testapp")
	comm.Send("hello_from_host")
	comm.Recv("lifecycle_visible")
	comm.Recv("size", &pixelsPerPt, &orientation)
	if pixelsPerPt < 0.1 {
		t.Fatalf("bad pixelsPerPt: %f", pixelsPerPt)
	}

	// A single paint event is sent when the lifecycle enters
	// StageVisible, and after the end of a touch event.
	var color string
	comm.Recv("paint", &color)
	// Ignore the first paint color, it may be slow making it to the screen.

	rotate(rotationLandscape)
	comm.Recv("size", &pixelsPerPt, &orientation)
	if want := size.OrientationLandscape; orientation != want {
		t.Errorf("want orientation %d, got %d", want, orientation)
	}

	var x, y int
	var ty string

	tap(t, 50, 260)
	comm.Recv("touch", &ty, &x, &y)
	if ty != "begin" || x != 50 || y != 260 {
		t.Errorf("want touch begin(50, 260), got %s(%d,%d)", ty, x, y)
	}
	comm.Recv("touch", &ty, &x, &y)
	if ty != "end" || x != 50 || y != 260 {
		t.Errorf("want touch end(50, 260), got %s(%d,%d)", ty, x, y)
	}

	comm.Recv("paint", &color)
	if gotColor := currentColor(t); color != gotColor {
		t.Errorf("app reports color %q, but saw %q", color, gotColor)
	}

	rotate(rotationPortrait)
	comm.Recv("size", &pixelsPerPt, &orientation)
	if want := size.OrientationPortrait; orientation != want {
		t.Errorf("want orientation %d, got %d", want, orientation)
	}

	tap(t, 50, 260)
	comm.Recv("touch", &ty, &x, &y) // touch begin
	comm.Recv("touch", &ty, &x, &y) // touch end
	comm.Recv("paint", &color)
	if gotColor := currentColor(t); color != gotColor {
		t.Errorf("app reports color %q, but saw %q", color, gotColor)
	}

	// TODO: lifecycle testing (NOTE: adb shell input keyevent 4 is the back button)
}

func currentColor(t *testing.T) string {
	file := fmt.Sprintf("app-screen-%d.png", time.Now().Unix())

	run(t, "adb", "shell", "screencap", "-p", "/data/local/tmp/"+file)
	run(t, "adb", "pull", "/data/local/tmp/"+file)
	run(t, "adb", "shell", "rm", "/data/local/tmp/"+file)
	defer os.Remove(file)

	f, err := os.Open(file)
	if err != nil {
		t.Errorf("currentColor: cannot open screencap: %v", err)
		return ""
	}
	m, _, err := image.Decode(f)
	if err != nil {
		t.Errorf("currentColor: cannot decode screencap: %v", err)
		return ""
	}
	var center color.Color
	{
		b := m.Bounds()
		x, y := b.Min.X+(b.Max.X-b.Min.X)/2, b.Min.Y+(b.Max.Y-b.Min.Y)/2
		center = m.At(x, y)
	}
	r, g, b, _ := center.RGBA()
	switch {
	case r == 0xffff && g == 0x0000 && b == 0x0000:
		return "red"
	case r == 0x0000 && g == 0xffff && b == 0x0000:
		return "green"
	case r == 0x0000 && g == 0x0000 && b == 0xffff:
		return "blue"
	default:
		return fmt.Sprintf("indeterminate: %v", center)
	}
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
