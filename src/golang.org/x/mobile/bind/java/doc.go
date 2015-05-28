// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package java implements the Java language bindings.
//
// See the design document (http://golang.org/s/gobind).
//
// Currently, this works only for android.
package java

// Init initializes communication with Java.
// Typically called from the Start callback in app.Run.
func Init() {
	initSeq()
}
