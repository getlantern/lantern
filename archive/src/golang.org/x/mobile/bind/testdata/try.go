// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package try has a name that is a Java keyword.
// Gobind has to translate it usefully. See Issue #12273.
package try

func This() string { return "This" }
