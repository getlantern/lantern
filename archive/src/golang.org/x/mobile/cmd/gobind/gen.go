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

func genPkg(p *types.Package, allPkg []*types.Package) {
	fname := defaultFileName(*lang, p)
	conf := &bind.GeneratorConfig{
		Fset:   fset,
		Pkg:    p,
		AllPkg: allPkg,
	}
	switch *lang {
	case "java":
		w, closer := writer(fname)
		conf.Writer = w
		processErr(bind.GenJava(conf, *javaPkg, bind.Java))
		closer()
		cname := "java_" + p.Name() + ".c"
		w, closer = writer(cname)
		conf.Writer = w
		processErr(bind.GenJava(conf, *javaPkg, bind.JavaC))
		closer()
		hname := p.Name() + ".h"
		w, closer = writer(hname)
		conf.Writer = w
		processErr(bind.GenJava(conf, *javaPkg, bind.JavaH))
		closer()
	case "go":
		w, closer := writer(fname)
		conf.Writer = w
		processErr(bind.GenGo(conf))
		closer()
	case "objc":
		gohname := p.Name() + ".h"
		w, closer := writer(gohname)
		conf.Writer = w
		processErr(bind.GenObjc(conf, *prefix, bind.ObjcGoH))
		closer()
		hname := fname[:len(fname)-2] + ".h"
		w, closer = writer(hname)
		conf.Writer = w
		processErr(bind.GenObjc(conf, *prefix, bind.ObjcH))
		closer()
		w, closer = writer(fname)
		conf.Writer = w
		processErr(bind.GenObjc(conf, *prefix, bind.ObjcM))
		closer()
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

func writer(fname string) (w io.Writer, closer func()) {
	if *outdir == "" {
		return os.Stdout, func() { return }
	}

	name := filepath.Join(*outdir, fname)
	dir := filepath.Dir(name)
	if err := os.MkdirAll(dir, 0755); err != nil {
		errorf("invalid output dir: %v", err)
		os.Exit(exitStatus)
	}

	f, err := os.Create(name)
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
	switch lang {
	case "java":
		firstRune, size := utf8.DecodeRuneInString(pkg.Name())
		className := string(unicode.ToUpper(firstRune)) + pkg.Name()[size:]
		return className + ".java"
	case "go":
		return "go_" + pkg.Name() + ".go"
	case "objc":
		firstRune, size := utf8.DecodeRuneInString(pkg.Name())
		className := string(unicode.ToUpper(firstRune)) + pkg.Name()[size:]
		return "Go" + className + ".m"
	}
	errorf("unknown target language: %q", lang)
	os.Exit(exitStatus)
	return ""
}
