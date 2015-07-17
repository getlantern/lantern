#!/usr/bin/env bash
#
# This command is based on instructions from
# https://godoc.org/golang.org/x/mobile/cmd/gobind.
#
# Copyright 2014 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

if [ ! -f make.bash ]; then
  echo 'Error running make.bash'
	exit 1
fi

ANDROID_APP=$PWD/../app
GIT_REVISION=$1
REVISION_DATE=$2
BUILD_DATE=$3
LOGGLY_TOKEN=d730c074-1f0a-415d-8d71-1ebf1d8bd736

mkdir -p gen src

mkdir -p $ANDROID_APP/src/org/getlantern
mkdir -p $ANDROID_APP/src/go
mkdir -p $ANDROID_APP/libs/armeabi-v7a

(cd $GOPATH/src/golang.org/x/mobile && cp $PWD/app/*.java $ANDROID_APP/src/go)
(cd $GOPATH/src/golang.org/x/mobile && cp $PWD/bind/java/Seq.java $ANDROID_APP/src/go)
CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 go build -ldflags="-shared -w -X main.version $GIT_REVISION -X main.revisionDate $REVISION_DATE -X main.buildDate $BUILD_DATE -X github.com/getlantern/flashlight/logging.logglyToken $LOGGLY_TOKEN" -o $ANDROID_APP/libs/armeabi-v7a/libgojni.so *.go
mv ./bindings/Flashlight.java $ANDROID_APP/src/org/getlantern
cp AndroidManifest.xml $ANDROID_APP
cp -r gen $ANDROID_APP
mkdir -p $ANDROID_APP/res
ant debug
