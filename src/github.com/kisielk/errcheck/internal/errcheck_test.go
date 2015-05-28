package errcheck

import (
	"go/build"
	"go/parser"
	"go/token"
	"testing"
)

const testPackage = "github.com/kisielk/errcheck/testdata"

var (
	unchecked map[marker]bool
	blank     map[marker]bool
)

type marker struct {
	file string
	line int
}

func init() {
	unchecked = make(map[marker]bool)
	blank = make(map[marker]bool)

	pkg, err := build.Import(testPackage, "", 0)
	if err != nil {
		panic("failed to import test package")
	}
	fset := token.NewFileSet()
	astPkg, err := parser.ParseDir(fset, pkg.Dir, nil, parser.ParseComments)
	if err != nil {
		panic("failed to parse test package")
	}

	for _, file := range astPkg["main"].Files {
		for _, comment := range file.Comments {
			text := comment.Text()
			pos := fset.Position(comment.Pos())
			switch text {
			case "UNCHECKED\n":
				unchecked[marker{pos.Filename, pos.Line}] = true
			case "BLANK\n":
				blank[marker{pos.Filename, pos.Line}] = true
			}
		}
	}
}

// TestUnchecked runs a test against the example files and ensures all unchecked errors are caught.
func TestUnchecked(t *testing.T) {
	checker := &Checker{
		Asserts: true,
	}
	err := checker.CheckPackages(testPackage)
	uerr, ok := err.(UncheckedErrors)
	if !ok {
		t.Fatal("wrong error type returned")
	}

	numErrors := len(unchecked)
	if len(uerr.Errors) != numErrors {
		t.Errorf("got %d errors, want %d", len(uerr.Errors), numErrors)
		for i, err := range uerr.Errors {
			t.Errorf("%d: %v", i, err)
		}
		return
	}

	for i, err := range uerr.Errors {
		uerr, ok := err.(uncheckedError)
		if !ok {
			t.Errorf("%d: not an uncheckedError, got %v", i, err)
			continue
		}
		m := marker{uerr.pos.Filename, uerr.pos.Line}
		if !unchecked[m] {
			t.Errorf("%d: unexpected error: %v", i, uerr)
		}
	}
}

// TestBlank is like TestUnchecked but also ensures assignments to the blank identifier are caught.
func TestBlank(t *testing.T) {
	checker := &Checker{
		Asserts: true,
		Blank:   true,
	}
	err := checker.CheckPackages(testPackage)
	uerr, ok := err.(UncheckedErrors)
	if !ok {
		t.Fatal("wrong error type returned")
	}

	numErrors := len(unchecked) + len(blank)
	if len(uerr.Errors) != numErrors {
		t.Errorf("got %d errors, want %d", len(uerr.Errors), numErrors)
		for i, err := range uerr.Errors {
			t.Errorf("%d: %v", i, err)
		}
		return
	}

	for i, err := range uerr.Errors {
		uerr, ok := err.(uncheckedError)
		if !ok {
			t.Errorf("%d: not an uncheckedError, got %v", i, err)
			continue
		}
		m := marker{uerr.pos.Filename, uerr.pos.Line}
		if !unchecked[m] && !blank[m] {
			t.Errorf("%d: unexpected error: %v", i, uerr)
		}
	}
}
