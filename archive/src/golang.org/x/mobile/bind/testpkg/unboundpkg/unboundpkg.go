// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package simplepkg is imported from testpkg and tests
// that references to other, unbound packages, are ignored.
package unboundpkg

type (
	S struct{}
	I interface{}
)
