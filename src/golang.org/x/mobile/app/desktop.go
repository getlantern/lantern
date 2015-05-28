// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux,!android darwin

package app

import (
	"os"
	"path/filepath"
)

// Logic shared by desktop debugging implementations.

func openAsset(name string) (ReadSeekCloser, error) {
	if !filepath.IsAbs(name) {
		name = filepath.Join("assets", name)
	}
	f, err := os.Open(name)
	if err != nil {
		return nil, err
	}
	return f, nil
}
