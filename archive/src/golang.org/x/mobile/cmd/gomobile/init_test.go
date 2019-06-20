// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"text/template"
)

var gopath string

func TestInit(t *testing.T) {
	buf := new(bytes.Buffer)
	gopathorig := os.Getenv("GOPATH")
	defer func() {
		xout = os.Stderr
		buildN = false
		buildX = false
		initU = false
		os.Setenv("GOPATH", gopathorig)
	}()
	xout = buf
	buildN = true
	buildX = true
	initU = true

	// Test that first GOPATH element is chosen correctly.
	gopath = "/GOPATH1"
	paths := []string{gopath, "/path2", "/path3"}
	if goos == "windows" {
		gopath = filepath.ToSlash(`C:\GOPATH1`)
		paths = []string{gopath, `C:\PATH2`, `C:\PATH3`}
	}
	os.Setenv("GOPATH", strings.Join(paths, string(os.PathListSeparator)))
	os.Setenv("GOROOT_BOOTSTRAP", "go1.4")
	if goos == "windows" {
		os.Setenv("HOMEDRIVE", "C:")
	}

	// TODO(hyangah): test with go1_6.
	err := runInit(cmdInit)
	if err != nil {
		t.Log(buf.String())
		t.Fatal(err)
	}

	diff, err := diffOutput(buf.String(), initTmpl)
	if err != nil {
		t.Fatalf("computing diff failed: %v", err)
	}
	if diff != "" {
		t.Errorf("unexpected output:\n%s", diff)
	}
}

func diffOutput(got string, wantTmpl *template.Template) (string, error) {
	got = filepath.ToSlash(got)

	wantBuf := new(bytes.Buffer)
	data := defaultOutputData()
	if err := wantTmpl.Execute(wantBuf, data); err != nil {
		return "", err
	}
	want := wantBuf.String()
	if got != want {
		return diff(got, want)
	}
	return "", nil
}

type outputData struct {
	NDK       string
	GOOS      string
	GOARCH    string
	GOPATH    string
	NDKARCH   string
	EXE       string // .extension for executables. (ex. ".exe" for windows)
	Xproj     string
	Xcontents string
	Xinfo     infoplistTmplData
	NumCPU    string
}

func defaultOutputData() outputData {
	data := outputData{
		NDK:       ndkVersion,
		GOOS:      goos,
		GOARCH:    goarch,
		GOPATH:    gopath,
		NDKARCH:   ndkarch,
		Xproj:     projPbxproj,
		Xcontents: contentsJSON,
		Xinfo:     infoplistTmplData{BundleID: "org.golang.todo.basic", Name: "Basic"},
		NumCPU:    strconv.Itoa(runtime.NumCPU()),
	}
	if goos == "windows" {
		data.EXE = ".exe"
	}
	return data
}

var initTmpl = template.Must(template.New("output").Parse(`GOMOBILE={{.GOPATH}}/pkg/gomobile
mkdir -p $GOMOBILE/android-{{.NDK}}
WORK={{.GOPATH}}/pkg/gomobile/work
mkdir -p $GOMOBILE/dl
curl -o$GOMOBILE/dl/gomobile-{{.NDK}}-{{.GOOS}}-{{.NDKARCH}}.tar.gz https://dl.google.com/go/mobile/gomobile-{{.NDK}}-{{.GOOS}}-{{.NDKARCH}}.tar.gz
tar xfz $GOMOBILE/dl/gomobile-{{.NDK}}-{{.GOOS}}-{{.NDKARCH}}.tar.gz
mkdir -p $GOMOBILE/android-{{.NDK}}/arm/sysroot
mv $WORK/android-{{.NDK}}/platforms/android-15/arch-arm/usr $GOMOBILE/android-{{.NDK}}/arm/sysroot/usr
mv $WORK/android-{{.NDK}}/toolchains/arm-linux-androideabi-4.9/prebuilt/{{.GOOS}}-{{.NDKARCH}}/bin $GOMOBILE/android-{{.NDK}}/arm/bin
mv $WORK/android-{{.NDK}}/toolchains/arm-linux-androideabi-4.9/prebuilt/{{.GOOS}}-{{.NDKARCH}}/lib $GOMOBILE/android-{{.NDK}}/arm/lib
mv $WORK/android-{{.NDK}}/toolchains/arm-linux-androideabi-4.9/prebuilt/{{.GOOS}}-{{.NDKARCH}}/libexec $GOMOBILE/android-{{.NDK}}/arm/libexec
mkdir -p $GOMOBILE/android-{{.NDK}}/arm/arm-linux-androideabi/bin
ln -s $GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-ld{{.EXE}} $GOMOBILE/android-{{.NDK}}/arm/arm-linux-androideabi/bin/ld{{.EXE}}
ln -s $GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-as{{.EXE}} $GOMOBILE/android-{{.NDK}}/arm/arm-linux-androideabi/bin/as{{.EXE}}
ln -s $GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-gcc{{.EXE}} $GOMOBILE/android-{{.NDK}}/arm/arm-linux-androideabi/bin/gcc{{.EXE}}
ln -s $GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-g++{{.EXE}} $GOMOBILE/android-{{.NDK}}/arm/arm-linux-androideabi/bin/g++{{.EXE}}
mkdir -p $GOMOBILE/dl
curl -o$GOMOBILE/dl/gomobile-openal-soft-1.16.0.1.tar.gz https://dl.google.com/go/mobile/gomobile-openal-soft-1.16.0.1.tar.gz
tar xfz $GOMOBILE/dl/gomobile-openal-soft-1.16.0.1.tar.gz
cp -r $WORK/openal/include/AL $GOMOBILE/android-{{.NDK}}/arm/sysroot/usr/include/AL
mkdir -p $GOMOBILE/android-{{.NDK}}/openal
mv $WORK/openal/lib $GOMOBILE/android-{{.NDK}}/openal/lib{{if eq .GOOS "darwin"}}
go install -p={{.NumCPU}} -x golang.org/x/mobile/gl
go install -p={{.NumCPU}} -x golang.org/x/mobile/app
go install -p={{.NumCPU}} -x golang.org/x/mobile/exp/app/debug{{end}}
GOOS=android GOARCH=arm CC=$GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-gcc{{.EXE}} CXX=$GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-g++{{.EXE}} CGO_ENABLED=1 GOARM=7 go install -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_android_arm -x std
{{if eq .GOOS "darwin"}}GOOS=darwin GOARCH=arm GOARM=7 CC=clang-iphoneos CXX=clang-iphoneos CGO_CFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch armv7 CGO_LDFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch armv7 CGO_ENABLED=1 go install -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_darwin_arm -x std
GOOS=darwin GOARCH=arm64 CC=clang-iphoneos CXX=clang-iphoneos CGO_CFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch arm64 CGO_LDFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch arm64 CGO_ENABLED=1 go install -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_darwin_arm64 -x std
GOOS=darwin GOARCH=amd64 CC=clang-iphonesimulator CXX=clang-iphonesimulator CGO_CFLAGS=-isysroot=iphonesimulator -mios-simulator-version-min=6.1 -arch x86_64 CGO_LDFLAGS=-isysroot=iphonesimulator -mios-simulator-version-min=6.1 -arch x86_64 CGO_ENABLED=1 go install -p={{.NumCPU}} -tags=ios -pkgdir=$GOMOBILE/pkg_darwin_amd64 -x std
{{end}}go version > $GOMOBILE/version
rm -r -f "$WORK"
`))
