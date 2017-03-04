// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package secondpkg is imported by bind tests that verify
// that a bound package can reference another bound package.
package secondpkg

type (
	Ser interface {
		S(_ *S)
	}

	IF interface {
		F()
	}

	I interface {
		F(i int) int
	}

	S struct{}
)

func (_ *S) F(i int) int {
	return i
}

const HelloString = "secondpkg string"

func Hello() string {
	return HelloString
}
