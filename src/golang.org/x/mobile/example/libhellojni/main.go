// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
This example program compiles to a gojni.so shared library, that can
be loaded from an android application. Build it by configuring a cross
compiler (see go.mobile/README) and then running:

ANDROID_APP=/path/to/Myapp/app ./make.bash

This program expects app/Go.java to be included in the Android
project, along with a Java class named Demo defining

	public static native void hello();

calling hello prints "Hello, world!" to logcat.

This is a very early example program that does not represent the
intended development model for Go on Android. A language binding
generator will follow, as will gradle build system integration.
The result will be no make.bash, and no need to write C.
*/
package main

import "golang.org/x/mobile/app"

func main() {
	app.Run(app.Callbacks{})
}
