// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build linux,!android darwin,!arm,!arm64 windows

package asset

import (
	"os"
	"path/filepath"
)

func openAsset(name string) (File, error) {
	if !filepath.IsAbs(name) {
		name = filepath.Join("assets", name)
	}
	f, err := os.Open(name)
	if err != nil {
		return nil, err
	}
	return f, nil
}
