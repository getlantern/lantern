// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"io"
	"path/filepath"

	"go/ast"
	"go/build"
	"go/parser"
	"go/scanner"
	"go/token"

	"golang.org/x/mobile/bind"
	"golang.org/x/tools/go/loader"
)

func genPkg(w io.Writer, pkg *build.Package) {
	if len(pkg.CgoFiles) > 0 {
		errorf("gobind: cannot use cgo-dependent package as service definition: %s", pkg.CgoFiles[0])
		return
	}

	files := parseFiles(pkg.Dir, pkg.GoFiles)
	if len(files) == 0 {
		return // some error has been reported
	}

	conf := loader.Config{
		SourceImports: true,
		Fset:          fset,
	}
	conf.TypeChecker.Error = func(err error) {
		errorf("%v", err)
	}
	conf.CreateFromFiles(pkg.ImportPath, files...)
	program, err := conf.Load()
	if err != nil {
		errorf("%v", err)
		return
	}
	p := program.Created[0].Pkg

	switch *lang {
	case "java":
		err = bind.GenJava(w, fset, p)
	case "go":
		err = bind.GenGo(w, fset, p)
	default:
		errorf("unknown target language: %q", *lang)
	}

	if err != nil {
		if list, _ := err.(bind.ErrorList); len(list) > 0 {
			for _, err := range list {
				errorf("%v", err)
			}
		} else {
			errorf("%v", err)
		}
	}
}

var fset = token.NewFileSet()

func parseFiles(dir string, filenames []string) []*ast.File {
	var files []*ast.File
	hasErr := false
	for _, filename := range filenames {
		path := filepath.Join(dir, filename)
		file, err := parser.ParseFile(fset, path, nil, parser.AllErrors)
		if err != nil {
			hasErr = true
			if list, _ := err.(scanner.ErrorList); len(list) > 0 {
				for _, err := range list {
					errorf("%v", err)
				}
			} else {
				errorf("%v", err)
			}
		}
		files = append(files, file)
	}
	if hasErr {
		return nil
	}
	return files
}
