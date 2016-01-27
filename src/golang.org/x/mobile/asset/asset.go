// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux windows

package asset

import "io"

// Open opens a named asset.
//
// Errors are of type *os.PathError.
//
// This must not be called from init when used in android apps.
func Open(name string) (File, error) {
	return openAsset(name)
}

// File is an open asset.
type File interface {
	io.ReadSeeker
	io.Closer
}
