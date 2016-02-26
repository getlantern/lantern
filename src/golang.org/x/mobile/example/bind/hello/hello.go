// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package hello is a trivial package for gomobile bind example.
package hello

import "fmt"

func Greetings(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}
