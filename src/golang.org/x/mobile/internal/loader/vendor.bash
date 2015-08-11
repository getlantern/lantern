#!/usr/bin/env bash

# Copyright 2015 The Go Authors.  All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Run this script to obtain an up-to-date vendored version of go/loader.

set -e

if [ ! -f vendor.bash ]; then
	echo 'vendor.bash must be run from the loader directory' 1>&2
	exit 1
fi

rm -f *.go
for f in cgo.go loader.go util.go; do
	cp $GOPATH/src/golang.org/x/tools/go/loader/$f .
done

patch -p1 < vendor.patch
