// Copyright (c) 2013 The Go Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd.

package lint

import (
	"bytes"
	"flag"
	"fmt"
	"go/ast"
	"go/parser"
	"go/printer"
	"go/token"
	"io/ioutil"
	"path"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"golang.org/x/tools/go/types"
)

var lintMatch = flag.String("lint.match", "", "restrict testdata matches to this pattern")

func TestAll(t *testing.T) {
	l := new(Linter)
	rx, err := regexp.Compile(*lintMatch)
	if err != nil {
		t.Fatalf("Bad -lint.match value %q: %v", *lintMatch, err)
	}

	baseDir := "testdata"
	fis, err := ioutil.ReadDir(baseDir)
	if err != nil {
		t.Fatalf("ioutil.ReadDir: %v", err)
	}
	if len(fis) == 0 {
		t.Fatalf("no files in %v", baseDir)
	}
	for _, fi := range fis {
		if !rx.MatchString(fi.Name()) {
			continue
		}
		//t.Logf("Testing %s", fi.Name())
		src, err := ioutil.ReadFile(path.Join(baseDir, fi.Name()))
		if err != nil {
			t.Fatalf("Failed reading %s: %v", fi.Name(), err)
		}

		ins := parseInstructions(t, fi.Name(), src)
		if ins == nil {
			t.Errorf("Test file %v does not have instructions", fi.Name())
			continue
		}

		ps, err := l.Lint(fi.Name(), src)
		if err != nil {
			t.Errorf("Linting %s: %v", fi.Name(), err)
			continue
		}

		for _, in := range ins {
			ok := false
			for i, p := range ps {
				if p.Position.Line != in.Line {
					continue
				}
				if in.Match.MatchString(p.Text) {
					// remove this problem from ps
					copy(ps[i:], ps[i+1:])
					ps = ps[:len(ps)-1]

					//t.Logf("/%v/ matched at %s:%d", in.Match, fi.Name(), in.Line)
					ok = true
					break
				}
			}
			if !ok {
				t.Errorf("Lint failed at %s:%d; /%v/ did not match", fi.Name(), in.Line, in.Match)
			}
		}
		for _, p := range ps {
			t.Errorf("Unexpected problem at %s:%d: %v", fi.Name(), p.Position.Line, p.Text)
		}
	}
}

type instruction struct {
	Line  int            // the line number this applies to
	Match *regexp.Regexp // what pattern to match
}

// parseInstructions parses instructions from the comments in a Go source file.
// It returns nil if none were parsed.
func parseInstructions(t *testing.T, filename string, src []byte) []instruction {
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, filename, src, parser.ParseComments)
	if err != nil {
		t.Fatalf("Test file %v does not parse: %v", filename, err)
	}
	var ins []instruction
	for _, cg := range f.Comments {
		ln := fset.Position(cg.Pos()).Line
		raw := cg.Text()
		for _, line := range strings.Split(raw, "\n") {
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			if line == "OK" && ins == nil {
				// so our return value will be non-nil
				ins = make([]instruction, 0)
				continue
			}
			if strings.Contains(line, "MATCH") {
				rx, err := extractPattern(line)
				if err != nil {
					t.Fatalf("At %v:%d: %v", filename, ln, err)
				}
				matchLine := ln
				if i := strings.Index(line, "MATCH:"); i >= 0 {
					// This is a match for a different line.
					lns := strings.TrimPrefix(line[i:], "MATCH:")
					lns = lns[:strings.Index(lns, " ")]
					matchLine, err = strconv.Atoi(lns)
					if err != nil {
						t.Fatalf("Bad match line number %q at %v:%d: %v", lns, filename, ln, err)
					}
				}
				ins = append(ins, instruction{
					Line:  matchLine,
					Match: rx,
				})
			}
		}
	}
	return ins
}

func extractPattern(line string) (*regexp.Regexp, error) {
	a, b := strings.Index(line, "/"), strings.LastIndex(line, "/")
	if a == -1 || a == b {
		return nil, fmt.Errorf("malformed match instruction %q", line)
	}
	pat := line[a+1 : b]
	rx, err := regexp.Compile(pat)
	if err != nil {
		return nil, fmt.Errorf("bad match pattern %q: %v", pat, err)
	}
	return rx, nil
}

func render(fset *token.FileSet, x interface{}) string {
	var buf bytes.Buffer
	if err := printer.Fprint(&buf, fset, x); err != nil {
		panic(err)
	}
	return buf.String()
}

func TestLine(t *testing.T) {
	tests := []struct {
		src    string
		offset int
		want   string
	}{
		{"single line file", 5, "single line file"},
		{"single line file with newline\n", 5, "single line file with newline\n"},
		{"first\nsecond\nthird\n", 2, "first\n"},
		{"first\nsecond\nthird\n", 9, "second\n"},
		{"first\nsecond\nthird\n", 14, "third\n"},
		{"first\nsecond\nthird with no newline", 16, "third with no newline"},
		{"first byte\n", 0, "first byte\n"},
	}
	for _, test := range tests {
		got := srcLine([]byte(test.src), token.Position{Offset: test.offset})
		if got != test.want {
			t.Errorf("srcLine(%q, offset=%d) = %q, want %q", test.src, test.offset, got, test.want)
		}
	}
}

func TestLintName(t *testing.T) {
	tests := []struct {
		name, want string
	}{
		{"foo_bar", "fooBar"},
		{"foo_bar_baz", "fooBarBaz"},
		{"Foo_bar", "FooBar"},
		{"foo_WiFi", "fooWiFi"},
		{"id", "id"},
		{"Id", "ID"},
		{"foo_id", "fooID"},
		{"fooId", "fooID"},
		{"fooUid", "fooUID"},
		{"idFoo", "idFoo"},
		{"uidFoo", "uidFoo"},
		{"midIdDle", "midIDDle"},
		{"APIProxy", "APIProxy"},
		{"ApiProxy", "APIProxy"},
		{"apiProxy", "apiProxy"},
		{"_Leading", "_Leading"},
		{"___Leading", "_Leading"},
		{"trailing_", "trailing"},
		{"trailing___", "trailing"},
		{"a_b", "aB"},
		{"a__b", "aB"},
		{"a___b", "aB"},
		{"Rpc1150", "RPC1150"},
		{"case3_1", "case3_1"},
		{"case3__1", "case3_1"},
		{"IEEE802_16bit", "IEEE802_16bit"},
		{"IEEE802_16Bit", "IEEE802_16Bit"},
	}
	for _, test := range tests {
		got := lintName(test.name)
		if got != test.want {
			t.Errorf("lintName(%q) = %q, want %q", test.name, got, test.want)
		}
	}
}

func TestExportedType(t *testing.T) {
	tests := []struct {
		typString string
		exp       bool
	}{
		{"int", true},
		{"string", false}, // references the shadowed builtin "string"
		{"T", true},
		{"t", false},
		{"*T", true},
		{"*t", false},
		{"map[int]complex128", true},
	}
	for _, test := range tests {
		src := `package foo; type T int; type t int; type string struct{}`
		fset := token.NewFileSet()
		file, err := parser.ParseFile(fset, "foo.go", src, 0)
		if err != nil {
			t.Fatalf("Parsing %q: %v", src, err)
		}
		// use the package name as package path
		pkg, err := types.Check(file.Name.Name, fset, []*ast.File{file})
		if err != nil {
			t.Fatalf("Type checking %q: %v", src, err)
		}
		// Use the first child scope of the package, which will be the file scope.
		scope := pkg.Scope().Child(0)
		tv, err := types.Eval(test.typString, pkg, scope)
		if err != nil {
			t.Errorf("types.Eval(%q): %v", test.typString, err)
			continue
		}
		if got := exportedType(tv.Type); got != test.exp {
			t.Errorf("exportedType(%v) = %t, want %t", tv.Type, got, test.exp)
		}
	}
}
