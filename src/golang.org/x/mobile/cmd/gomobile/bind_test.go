// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"text/template"
)

// TODO(crawshaw): TestBindIOS

func TestBindAndroid(t *testing.T) {
	if os.Getenv("ANDROID_HOME") == "" {
		t.Skip("ANDROID_HOME not found, skipping bind")
	}

	buf := new(bytes.Buffer)
	defer func() {
		xout = os.Stderr
		buildN = false
		buildX = false
	}()
	xout = buf
	buildN = true
	buildX = true
	buildO = "asset.aar"
	buildTarget = "android"
	gopath = filepath.SplitList(os.Getenv("GOPATH"))[0]
	if goos == "windows" {
		os.Setenv("HOMEDRIVE", "C:")
	}
	cmdBind.flag.Parse([]string{"golang.org/x/mobile/asset"})
	err := runBind(cmdBind)
	if err != nil {
		t.Log(buf.String())
		t.Fatal(err)
	}

	diff, err := diffOutput(buf.String(), bindAndroidTmpl)
	if err != nil {
		t.Fatalf("computing diff failed: %v", err)
	}
	if diff != "" {
		t.Errorf("unexpected output:\n%s", diff)
	}
}

var bindAndroidTmpl = template.Must(template.New("output").Parse(`GOMOBILE={{.GOPATH}}/pkg/gomobile
WORK=$WORK
gobind -lang=go golang.org/x/mobile/asset > $WORK/go_asset/go_assetmain.go
mkdir -p $WORK/go_asset
mkdir -p $WORK/androidlib
GOOS=android GOARCH=arm GOARM=7 CC=$GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-gcc{{.EXE}} CXX=$GOMOBILE/android-{{.NDK}}/arm/bin/arm-linux-androideabi-g++{{.EXE}} CGO_ENABLED=1 go build -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_android_arm -tags="" -x -buildmode=c-shared -o=$WORK/android/src/main/jniLibs/armeabi-v7a/libgojni.so $WORK/androidlib/main.go
gobind -lang=java golang.org/x/mobile/asset > $WORK/android/src/main/java/go/asset/Asset.java
mkdir -p $WORK/android/src/main/java/go/asset
mkdir -p $WORK/android/src/main/java/go
rm $WORK/android/src/main/java/go/Seq.java
ln -s $GOPATH/src/golang.org/x/mobile/bind/java/Seq.java $WORK/android/src/main/java/go/Seq.java
PWD=$WORK/android/src/main/java javac -d $WORK/javac-output -source 1.7 -target 1.7 -bootclasspath $ANDROID_HOME/platforms/android-22/android.jar *.java
jar c -C $WORK/javac-output .
`))
