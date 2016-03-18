// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package simplepkg is imported from testpkg and tests two
// corner cases.
// First: simplepkg itself contains no (exported) functions
// or methods and so its generated Go package must not import
// it.
//
// Second: even though testpkg imports simplepkg, testpkg's
// generated Go package ends up not referencing simplepkg and
// must not import it.
package simplepkg

type S struct{}
