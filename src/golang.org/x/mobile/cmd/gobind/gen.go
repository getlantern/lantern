// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"unicode"
	"unicode/utf8"

	"go/ast"
	"go/build"
	"go/parser"
	"go/scanner"
	"go/token"

	"golang.org/x/mobile/bind"
	"golang.org/x/tools/go/loader"
	"golang.org/x/tools/go/types"
)

func genPkg(pkg *build.Package) {
	if len(pkg.CgoFiles) > 0 {
		errorf("gobind: cannot use cgo-dependent package as service definition: %s", pkg.CgoFiles[0])
		return
	}

	files := parseFiles(pkg.Dir, pkg.GoFiles)
	if len(files) == 0 {
		return // some error has been reported
	}

	conf := loader.Config{
		Fset: fset,
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

	w, closer, err := writer(*lang, p)
	if err != nil {
		errorf("%v", err)
		return
	}

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
	if err := closer(); err != nil {
		errorf("error in closing output: %v", err)
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

func writer(lang string, pkg *types.Package) (w io.Writer, closer func() error, err error) {
	if *outdir == "" {
		return os.Stdout, func() error { return nil }, nil
	}

	// TODO(hakim): support output of multiple files e.g. .h/.m files for objc.

	if err := os.MkdirAll(*outdir, 0755); err != nil {
		return nil, nil, fmt.Errorf("invalid output dir: %v\n", err)
	}
	fname := defaultFileName(lang, pkg)
	f, err := os.Create(filepath.Join(*outdir, fname))
	if err != nil {
		return nil, nil, fmt.Errorf("invalid output dir: %v\n", err)
	}
	return f, f.Close, nil
}

func defaultFileName(lang string, pkg *types.Package) string {
	switch lang {
	case "java":
		firstRune, size := utf8.DecodeRuneInString(pkg.Name())
		className := string(unicode.ToUpper(firstRune)) + pkg.Name()[size:]
		return className + ".java"
	case "go":
		return "go_" + pkg.Name() + ".go"
	}
	errorf("unknown target language: %q", lang)
	os.Exit(exitStatus)
	return ""
}
