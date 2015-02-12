// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package bind implements a code generator for gobind.
//
// See the documentation on the gobind command for usage details.
package bind // import "golang.org/x/mobile/bind"

// TODO(crawshaw): slice support
// TODO(crawshaw): channel support

import (
	"bytes"
	"go/format"
	"go/token"
	"io"

	"golang.org/x/tools/go/types"
)

// GenJava generates a Java API from a Go package.
func GenJava(w io.Writer, fset *token.FileSet, pkg *types.Package) error {
	buf := new(bytes.Buffer)
	g := &javaGen{
		printer: &printer{buf: buf, indentEach: []byte("    ")},
		fset:    fset,
		pkg:     pkg,
	}
	if err := g.gen(); err != nil {
		return err
	}
	_, err := io.Copy(w, buf)
	return err
}

// GenGo generates a Go stub to support foreign language APIs.
func GenGo(w io.Writer, fset *token.FileSet, pkg *types.Package) error {
	buf := new(bytes.Buffer)
	g := &goGen{
		printer: &printer{buf: buf, indentEach: []byte("\t")},
		fset:    fset,
		pkg:     pkg,
	}
	if err := g.gen(); err != nil {
		return err
	}
	src := buf.Bytes()
	srcf, err := format.Source(src)
	if err != nil {
		w.Write(src) // for debugging
		return err
	}
	_, err = w.Write(srcf)
	return err
}
