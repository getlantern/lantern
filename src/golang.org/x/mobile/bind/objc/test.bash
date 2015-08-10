#!/usr/bin/env bash

# Copyright 2015 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# This is a script to compile and run SeqTest.

set -e

export GOARCH=amd64
export GOOS=darwin  # TODO: arm, arm64.
export CGO_ENABLED=1

WORK=`mktemp -d /tmp/objctest.XXXXX`
function cleanup() {
 rm -rf ${WORK}
}
trap cleanup EXIT

(cd testpkg; go generate)

go build -x -v -buildmode=c-archive -o=${WORK}/libgo.a test_main.go
cp ./seq.h ${WORK}/
cp testpkg/objc_testpkg/GoTestpkg.* ${WORK}/
cp ./SeqTest.m ${WORK}/

ccargs="-Wl,-no_pie -framework Foundation -fobjc-arc"
$(go env CC) $(go env GOGCCFLAGS) $ccargs -o ${WORK}/a.out ${WORK}/libgo.a ${WORK}/GoTestpkg.m ${WORK}/SeqTest.m

${WORK}/a.out
