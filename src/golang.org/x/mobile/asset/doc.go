// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package asset provides access to application-bundled assets.
//
// On Android, assets are accessed via android.content.res.AssetManager.
// These files are stored in the assets/ directory of the app. Any raw asset
// can be accessed by its direct relative name. For example assets/img.png
// can be opened with Open("img.png").
//
// On iOS an asset is a resource stored in the application bundle.
// Resources can be loaded using the same relative paths.
//
// For consistency when debugging on a desktop, assets are read from a
// directory named assets under the current working directory.
package asset // import "golang.org/x/mobile/asset"
