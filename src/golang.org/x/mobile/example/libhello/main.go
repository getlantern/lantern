// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This is the Go entry point for the libhello app.
// It is invoked from Java.
//
// See README for details.
package main

import (
	"golang.org/x/mobile/app"

	_ "golang.org/x/mobile/bind/java"
	_ "golang.org/x/mobile/example/libhello/hi/go_hi"
)

func main() {
	app.Run(app.Callbacks{})
}
