// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package parser

import (
	"os"
	"testing"

	"github.com/rogpeppe/godef/go/token"
)

var fset = token.NewFileSet()

var illegalInputs = []interface{}{
	nil,
	3.14,
	[]byte(nil),
	"foo!",
	`package p; func f() { if /* should have condition */ {} };`,
	`package p; func f() { if ; /* should have condition */ {} };`,
	`package p; func f() { if f(); /* should have condition */ {} };`,
}

func TestParseIllegalInputs(t *testing.T) {
	for _, src := range illegalInputs {
		_, err := ParseFile(fset, "", src, 0, nil)
		if err == nil {
			t.Errorf("ParseFile(%v) should have failed", src)
		}
	}
}

var validPrograms = []interface{}{
	"package p\n",
	`package p;`,
	`package p; import "fmt"; func f() { fmt.Println("Hello, World!") };`,
	`package p; func f() { if f(T{}) {} };`,
	`package p; func f() { _ = (<-chan int)(x) };`,
	`package p; func f() { _ = (<-chan <-chan int)(x) };`,
	`package p; func f(func() func() func());`,
	`package p; func f(...T);`,
	`package p; func f(float, ...int);`,
	`package p; func f(x int, a ...int) { f(0, a...); f(1, a...,) };`,
	`package p; type T []int; var a []bool; func f() { if a[T{42}[0]] {} };`,
	`package p; type T []int; func g(int) bool { return true }; func f() { if g(T{42}[0]) {} };`,
	`package p; type T []int; func f() { for _ = range []int{T{42}[0]} {} };`,
	`package p; var a = T{{1, 2}, {3, 4}}`,
	`package p; func f() { select { case <- c: case c <- d: case c <- <- d: case <-c <- d: } };`,
	`package p; func f() { if ; true {} };`,
	`package p; func f() { switch ; {} };`,
	`package p; func f() (int,) {}`,
	`package p; func _(x []int) { for range x {} }`,
}

func TestParseValidPrograms(t *testing.T) {
	for _, src := range validPrograms {
		_, err := ParseFile(fset, "", src, Trace, nil)
		if err != nil {
			t.Errorf("ParseFile(%q): %v", src, err)
		}
	}
}

var validFiles = []string{
	"parser.go",
	"parser_test.go",
}

func TestParse3(t *testing.T) {
	for _, filename := range validFiles {
		_, err := ParseFile(fset, filename, nil, DeclarationErrors, nil)
		if err != nil {
			t.Errorf("ParseFile(%s): %v", filename, err)
		}
	}
}

func nameFilter(filename string) bool {
	switch filename {
	case "parser.go":
	case "interface.go":
	case "parser_test.go":
	default:
		return false
	}
	return true
}

func dirFilter(f os.FileInfo) bool { return nameFilter(f.Name()) }

func TestParse4(t *testing.T) {
	path := "."
	pkgs, err := ParseDir(fset, path, dirFilter, 0)
	if err != nil {
		t.Fatalf("ParseDir(%s): %v", path, err)
	}
	if len(pkgs) != 1 {
		t.Errorf("incorrect number of packages: %d", len(pkgs))
	}
	pkg := pkgs["parser"]
	if pkg == nil {
		t.Errorf(`package "parser" not found`)
		return
	}
	for filename := range pkg.Files {
		if !nameFilter(filename) {
			t.Errorf("unexpected package file: %s", filename)
		}
	}
}
