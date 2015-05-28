#!/usr/bin/env bash
# Copyright 2014 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# See main.go for commentary.

set -e

if [ ! -f make.bash ]; then
	echo 'make.bash must be run from $GOPATH/src/golang.org/x/mobile/example/libhellojni'
	exit 1
fi
if [ -z "$ANDROID_APP" ]; then
	echo 'ERROR: Environment variable ANDROID_APP is unset.'
	exit 1
fi

mkdir -p $ANDROID_APP/src/main/jniLibs/armeabi \
	$ANDROID_APP/src/main/java/go \
	$ANDROID_APP/src/main/java/demo
(cd ../.. && ln -sf $PWD/app/*.java $ANDROID_APP/src/main/java/go)
(cd ../.. && ln -sf $PWD/bind/java/*.java $ANDROID_APP/src/main/java/go)
ln -sf $PWD/*.java $ANDROID_APP/src/main/java/demo
CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 \
	go build -ldflags="-shared" .
mv libhellojni $ANDROID_APP/src/main/jniLibs/armeabi/libgojni.so
