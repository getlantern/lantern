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

func TestIOSBuild(t *testing.T) {
	buf := new(bytes.Buffer)
	defer func() {
		xout = os.Stderr
		buildN = false
		buildX = false
	}()
	xout = buf
	buildN = true
	buildX = true
	buildO = "basic.app"
	buildTarget = "ios"
	gopath = filepath.SplitList(os.Getenv("GOPATH"))[0]
	cmdBuild.flag.Parse([]string{"golang.org/x/mobile/example/basic"})
	ctx.BuildTags = []string{"tag1"}
	err := runBuild(cmdBuild)
	if err != nil {
		t.Log(buf.String())
		t.Fatal(err)
	}

	diff, err := diffOutput(buf.String(), iosBuildTmpl)
	if err != nil {
		t.Fatalf("computing diff failed: %v", err)
	}
	if diff != "" {
		t.Errorf("unexpected output:\n%s", diff)
	}
}

var iosBuildTmpl = template.Must(infoplistTmpl.New("output").Parse(`GOMOBILE={{.GOPATH}}/pkg/gomobile
WORK=$WORK
mkdir -p $WORK/main.xcodeproj
echo "{{.Xproj}}" > $WORK/main.xcodeproj/project.pbxproj
mkdir -p $WORK/main
echo "{{template "infoplist" .Xinfo}}" > $WORK/main/Info.plist
mkdir -p $WORK/main/Images.xcassets/AppIcon.appiconset
echo "{{.Xcontents}}" > $WORK/main/Images.xcassets/AppIcon.appiconset/Contents.json
GOOS=darwin GOARCH=arm GOARM=7 CC=clang-iphoneos CXX=clang-iphoneos CGO_CFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch armv7 CGO_LDFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch armv7 CGO_ENABLED=1 go build -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_darwin_arm -tags="tag1,ios" -x -o=$WORK/arm golang.org/x/mobile/example/basic
GOOS=darwin GOARCH=arm64 CC=clang-iphoneos CXX=clang-iphoneos CGO_CFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch arm64 CGO_LDFLAGS=-isysroot=iphoneos -miphoneos-version-min=6.1 -arch arm64 CGO_ENABLED=1 go build -p={{.NumCPU}} -pkgdir=$GOMOBILE/pkg_darwin_arm64 -tags="tag1,ios" -x -o=$WORK/arm64 golang.org/x/mobile/example/basic
xcrun lipo -create $WORK/arm $WORK/arm64 -o $WORK/main/main
mkdir -p $WORK/main/assets
xcrun xcodebuild -configuration Release -project $WORK/main.xcodeproj
mv $WORK/build/Release-iphoneos/main.app basic.app
`))
