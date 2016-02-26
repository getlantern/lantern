// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"go/token"
	"go/types"
	"io"
	"os"
	"path/filepath"
	"unicode"
	"unicode/utf8"

	"golang.org/x/mobile/bind"
)

func genPkg(p *types.Package) {
	fname := defaultFileName(*lang, p)
	switch *lang {
	case "java":
		w, closer := writer(fname, p)
		processErr(bind.GenJava(w, fset, p, *javaPkg))
		closer()
	case "go":
		w, closer := writer(fname, p)
		processErr(bind.GenGo(w, fset, p))
		closer()
	case "objc":
		if fname == "" {
			processErr(bind.GenObjc(os.Stdout, fset, p, *prefix, true))
			processErr(bind.GenObjc(os.Stdout, fset, p, *prefix, false))
		} else {
			hname := fname[:len(fname)-2] + ".h"
			w, closer := writer(hname, p)
			processErr(bind.GenObjc(w, fset, p, *prefix, true))
			closer()
			w, closer = writer(fname, p)
			processErr(bind.GenObjc(w, fset, p, *prefix, false))
			closer()
		}
	default:
		errorf("unknown target language: %q", *lang)
	}
}

func processErr(err error) {
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

func writer(fname string, pkg *types.Package) (w io.Writer, closer func()) {
	if fname == "" {
		return os.Stdout, func() { return }
	}

	dir := filepath.Dir(fname)
	if err := os.MkdirAll(dir, 0755); err != nil {
		errorf("invalid output dir: %v", err)
		os.Exit(exitStatus)
	}

	f, err := os.Create(fname)
	if err != nil {
		errorf("invalid output dir: %v", err)
		os.Exit(exitStatus)
	}
	closer = func() {
		if err := f.Close(); err != nil {
			errorf("error in closing output file: %v", err)
		}
	}
	return f, closer
}

func defaultFileName(lang string, pkg *types.Package) string {
	if *outdir == "" {
		return ""
	}

	switch lang {
	case "java":
		firstRune, size := utf8.DecodeRuneInString(pkg.Name())
		className := string(unicode.ToUpper(firstRune)) + pkg.Name()[size:]
		return filepath.Join(*outdir, className+".java")
	case "go":
		return filepath.Join(*outdir, "go_"+pkg.Name()+".go")
	case "objc":
		firstRune, size := utf8.DecodeRuneInString(pkg.Name())
		className := string(unicode.ToUpper(firstRune)) + pkg.Name()[size:]
		return filepath.Join(*outdir, "Go"+className+".m")
	}
	errorf("unknown target language: %q", lang)
	os.Exit(exitStatus)
	return ""
}
