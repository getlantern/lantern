// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build ignore

// Dummy main used by test.bash to build testpkg.
package main

import "C"

import (
	_ "golang.org/x/mobile/bind/objc"
	_ "golang.org/x/mobile/bind/objc/testpkg/go_testpkg"
)

func main() {
	panic("not called in a c-archive")
}
