#!/usr/bin/env bash

# Copyright 2014 The Go Authors.  All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# For testing Android. Run from a repository root.
#   build/androidtest.bash
# The compiler runs locally, pushes the copy of the repository
# to a target device using adb, and runs tests in the device
# using adb shell commands.

set -e
ulimit -c 0 # no core files

function die() {
  echo "FAIL: $1"
  exit 1
}

if [ -z "${GOPATH}" ]; then
  die 'GOPATH must be set.'
fi

readonly CURDIR=`pwd`
if [ ! -f AUTHORS ]; then
  die 'androidtest.bash must be run from the repository root.'
fi

function pkg() {
  local paths=(${GOPATH//:/ })
  for e in "${paths[@]}"; do
    e="${e%/}"
    local relpath="${CURDIR#"${e}/src/"}"
    if [ "${relpath}" != "${CURDIR}" ]; then
       echo "${relpath}"
       break
    fi
  done
}

export PKG="$(pkg)"
if [ -z "${PKG}" ]; then
  die 'androidtest.bash failed to determine the repository package name.'
fi

export DEVICEDIR=/data/local/tmp/androidtest-$$
export TMPDIR=`mktemp -d /tmp/androidtest.XXXXX`

function cleanup() {
  echo '# Cleaning up...'
  rm -rf "$TMPDIR"
  adb shell rm -rf "${DEVICEDIR}"
}
trap cleanup EXIT

# 'adb sync' syncs data in ANDROID_PRODUCT_OUT directory.
# We copy the entire golang.org/x/mobile/... (with -p option to preserve
# file properties) to the directory assuming tests may depend only
# on data in the same subrepository.
echo '# Syncing test files to android device'
export ANDROID_PRODUCT_OUT="${TMPDIR}/androidtest-$$"
readonly LOCALDIR="${ANDROID_PRODUCT_OUT}/${DEVICEDIR}"

mkdir -p "${LOCALDIR}/${PKG}"
echo "cp -R --preserve=all ./* ${LOCALDIR}/${PKG}/"
cp -R --preserve=all ./* "${LOCALDIR}/${PKG}/"

time adb sync data &> /dev/null
echo ''

echo '# Run tests on android (arm7)'
# Build go_android_${GOARCH}_exec that will be invoked for
# GOOS=android GOARCH=$GOARCH go test/run.
mkdir -p "${TMPDIR}/bin"
export PATH=${TMPDIR}/bin:${PATH}
GOOS="${GOHOSTOS}" GOARCH="${GOHOSTARCH}" go build \
        -o "${TMPDIR}/bin/go_android_arm_exec" \
        "${GOPATH}/src/golang.org/x/mobile/build/go_android_exec.go"
CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 \
	go test ./...

# Special tests for mobile subrepository.
if [ "$PKG" = "golang.org/x/mobile" ]; then
	echo '# Run mobile=repository specific android tests.'

	cd "${CURDIR}/bind/java"; ./test.bash
fi

exit  0
