// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build !android

package font

import "io/ioutil"

func buildDefault() ([]byte, error) {
	return ioutil.ReadFile("/usr/share/fonts/truetype/droid/DroidSans.ttf")
}

func buildMonospace() ([]byte, error) {
	return ioutil.ReadFile("/usr/share/fonts/truetype/droid/DroidSansMono.ttf")
}
