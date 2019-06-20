// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"text/template"
)

func TestRFC1034Label(t *testing.T) {
	tests := []struct {
		in, want string
	}{
		{"a", "a"},
		{"123", "-23"},
		{"a.b.c", "a-b-c"},
		{"a-b", "a-b"},
		{"a:b", "a-b"},
		{"a?b", "a-b"},
		{"αβγ", "---"},
		{"💩", "--"},
		{"My App", "My-App"},
		{"...", ""},
		{".-.", "--"},
	}

	for _, tc := range tests {
		if got := rfc1034Label(tc.in); got != tc.want {
			t.Errorf("rfc1034Label(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestAndroidPkgName(t *testing.T) {
	tests := []struct {
		in, want string
	}{
		{"a", "a"},
		{"a123", "a123"},
		{"a.b.c", "a_b_c"},
		{"a-b", "a_b"},
		{"a:b", "a_b"},
		{"a?b", "a_b"},
		{"αβγ", "go___"},
		{"💩", "go_"},
		{"My App", "My_App"},
		{"...", "go___"},
		{".-.", "go___"},
		{"abstract", "abstract_"},
		{"Abstract", "Abstract"},
	}

	for _, tc := range tests {
		if got := androidPkgName(tc.in); got != tc.want {
			t.Errorf("len %d", len(tc.in))
			t.Errorf("androidPkgName(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestAndroidBuild(t *testing.T) {
	buf := new(bytes.Buffer)
	defer func() {
		xout = os.Stderr
		buildN = false
		buildX = false
	}()
	xout = buf
	buildN = true
	buildX = true
	buildO = "basic.apk"
	buildTarget = "android"
	gopath = filepath.ToSlash(filepath.SplitList(os.Getenv("GOPATH"))[0])
	if goos == "windows" {
		os.Setenv("HOMEDRIVE", "C:")
	}
	cmdBuild.flag.Parse([]string{"golang.org/x/mobile/example/basic"})
	ctx.BuildTags = []string{"tag1"}
	err := runBuild(cmdBuild)
	if err != nil {
		t.Log(buf.String())
		t.Fatal(err)
	}

	diff, err := diffOutput(buf.String(), androidBuildTmpl)
	if err != nil {
		t.Fatalf("computing diff failed: %v", err)
	}
	if diff != "" {
		t.Errorf("unexpected output:\n%s", diff)
	}
}

var androidBuildTmpl = template.Must(template.New("output").Parse(`GOMOBILE={{.GOPATH}}/pkg/gomobile
WORK=$WORK
mkdir -p $WORK/lib/armeabi-v7a
GOOS=android GOARCH=arm CC=$GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-gcc{{.EXE}} CXX=$GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-g++{{.EXE}} CGO_ENABLED=1 GOARM=7 go build -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_android_arm -tags="tag1" -x -buildmode=c-shared -o $WORK/lib/armeabi-v7a/libbasic.so golang.org/x/mobile/example/basic
`))

func TestParseBuildTargetFlag(t *testing.T) {
	androidArchs := "arm"
	iosArchs := "arm,arm64,amd64"

	tests := []struct {
		in        string
		wantErr   bool
		wantOS    string
		wantArchs string
	}{
		{"android", false, "android", androidArchs},
		{"android,android/arm", false, "android", androidArchs},
		{"android/arm", false, "android", "arm"},

		{"ios", false, "darwin", iosArchs},
		{"ios,ios/arm", false, "darwin", iosArchs},
		{"ios/arm", false, "darwin", "arm"},
		{"ios/amd64", false, "darwin", "amd64"},

		{"", true, "", ""},
		{"linux", true, "", ""},
		{"android/x86", true, "", ""},
		{"android/arm5", true, "", ""},
		{"ios/mips", true, "", ""},
		{"android,ios", true, "", ""},
		{"ios,android", true, "", ""},
	}

	for _, tc := range tests {
		gotOS, gotArchs, err := parseBuildTarget(tc.in)
		if tc.wantErr {
			if err == nil {
				t.Errorf("-target=%q; want error, got (%q, %q, nil)", tc.in, gotOS, gotArchs)
			}
			continue
		}
		if err != nil || gotOS != tc.wantOS || strings.Join(gotArchs, ",") != tc.wantArchs {
			t.Errorf("-target=%q; want (%v, [%v], nil), got (%q, %q, %v)",
				tc.in, tc.wantOS, tc.wantArchs, gotOS, gotArchs, err)
		}
	}
}
