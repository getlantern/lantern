// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This file contains the exported entry points for invoking the parser.

package parser

import (
	"bytes"
	"errors"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"

	"github.com/rogpeppe/godef/go/ast"
	"github.com/rogpeppe/godef/go/scanner"
	"github.com/rogpeppe/godef/go/token"
)

// If src != nil, readSource converts src to a []byte if possible;
// otherwise it returns an error. If src == nil, readSource returns
// the result of reading the file specified by filename.
//
func readSource(filename string, src interface{}) ([]byte, error) {
	if src != nil {
		switch s := src.(type) {
		case string:
			return []byte(s), nil
		case []byte:
			return s, nil
		case *bytes.Buffer:
			// is io.Reader, but src is already available in []byte form
			if s != nil {
				return s.Bytes(), nil
			}
		case io.Reader:
			var buf bytes.Buffer
			_, err := io.Copy(&buf, s)
			if err != nil {
				return nil, err
			}
			return buf.Bytes(), nil
		default:
			return nil, errors.New("invalid source")
		}
	}

	return ioutil.ReadFile(filename)
}

func (p *parser) parseEOF() error {
	p.expect(token.EOF)
	return p.GetError(scanner.Sorted)
}

// ParseExpr parses a Go expression and returns the corresponding
// AST node. The fset, filename, and src arguments have the same interpretation
// as for ParseFile. If there is an error, the result expression
// may be nil or contain a partial AST.
//
// if scope is non-nil, it will be used as the scope for the expression.
//
func ParseExpr(fset *token.FileSet, filename string, src interface{}, scope *ast.Scope) (ast.Expr, error) {
	data, err := readSource(filename, src)
	if err != nil {
		return nil, err
	}

	var p parser
	p.init(fset, filename, data, 0, scope)
	x := p.parseExpr()
	if p.tok == token.SEMICOLON {
		p.next() // consume automatically inserted semicolon, if any
	}
	return x, p.parseEOF()
}

// ParseStmtList parses a list of Go statements and returns the list
// of corresponding AST nodes. The fset, filename, and src arguments have the same
// interpretation as for ParseFile. If there is an error, the node
// list may be nil or contain partial ASTs.
//
// if scope is non-nil, it will be used as the scope for the statements.
//
func ParseStmtList(fset *token.FileSet, filename string, src interface{}, scope *ast.Scope) ([]ast.Stmt, error) {
	data, err := readSource(filename, src)
	if err != nil {
		return nil, err
	}

	var p parser
	p.init(fset, filename, data, 0, scope)
	return p.parseStmtList(), p.parseEOF()
}

// ParseDeclList parses a list of Go declarations and returns the list
// of corresponding AST nodes. The fset, filename, and src arguments have the same
// interpretation as for ParseFile. If there is an error, the node
// list may be nil or contain partial ASTs.
//
// If scope is non-nil, it will be used for declarations.
//
func ParseDeclList(fset *token.FileSet, filename string, src interface{}, scope *ast.Scope) ([]ast.Decl, error) {
	data, err := readSource(filename, src)
	if err != nil {
		return nil, err
	}

	var p parser
	p.init(fset, filename, data, 0, scope)
	p.pkgScope = scope
	p.fileScope = scope
	return p.parseDeclList(), p.parseEOF()
}

// ParseFile parses the source code of a single Go source file and returns
// the corresponding ast.File node. The source code may be provided via
// the filename of the source file, or via the src parameter.
//
// If src != nil, ParseFile parses the source from src and the filename is
// only used when recording position information. The type of the argument
// for the src parameter must be string, []byte, or io.Reader.
//
// If src == nil, ParseFile parses the file specified by filename.
//
// The mode parameter controls the amount of source text parsed and other
// optional parser functionality. Position information is recorded in the
// file set fset.
//
// If the source couldn't be read, the returned AST is nil and the error
// indicates the specific failure. If the source was read but syntax
// errors were found, the result is a partial AST (with ast.BadX nodes
// representing the fragments of erroneous source code). Multiple errors
// are returned via a scanner.ErrorList which is sorted by file position.
//
func ParseFile(fset *token.FileSet, filename string, src interface{}, mode uint, pkgScope *ast.Scope) (*ast.File, error) {
	data, err := readSource(filename, src)
	if err != nil {
		return nil, err
	}

	var p parser
	p.init(fset, filename, data, mode, pkgScope)
	p.pkgScope = p.topScope
	p.openScope()
	p.fileScope = p.topScope
	return p.parseFile(), p.GetError(scanner.NoMultiples) // parseFile() reads to EOF
}

func parseFileInPkg(fset *token.FileSet, pkgs map[string]*ast.Package, filename string, mode uint) (err error) {
	data, err := readSource(filename, nil)
	if err != nil {
		return err
	}
	// first find package name, so we can use the correct package
	// scope when parsing the file.
	src, err := ParseFile(fset, filename, data, PackageClauseOnly, nil)
	if err != nil {
		return
	}
	name := src.Name.Name
	pkg := pkgs[name]
	if pkg == nil {
		pkg = &ast.Package{name, ast.NewScope(Universe), nil, make(map[string]*ast.File)}
		pkgs[name] = pkg
	}
	src, err = ParseFile(fset, filename, data, mode, pkg.Scope)
	if err != nil {
		return
	}
	pkg.Files[filename] = src
	return
}

// ParseFiles calls ParseFile for each file in the filenames list and returns
// a map of package name -> package AST with all the packages found. The mode
// bits are passed to ParseFile unchanged. Position information is recorded
// in the file set fset.
//
// Files with parse errors are ignored. In this case the map of packages may
// be incomplete (missing packages and/or incomplete packages) and the first
// error encountered is returned.
//
func ParseFiles(fset *token.FileSet, filenames []string, mode uint) (pkgs map[string]*ast.Package, first error) {
	pkgs = make(map[string]*ast.Package)
	for _, filename := range filenames {
		if err := parseFileInPkg(fset, pkgs, filename, mode); err != nil && first == nil {
			first = err
		}
	}
	return
}

// ParseDir calls ParseFile for the files in the directory specified by path and
// returns a map of package name -> package AST with all the packages found. If
// filter != nil, only the files with os.FileInfo entries passing through the filter
// are considered. The mode bits are passed to ParseFile unchanged. Position
// information is recorded in the file set fset.
//
// If the directory couldn't be read, a nil map and the respective error are
// returned. If a parse error occurred, a non-nil but incomplete map and the
// error are returned.
//
func ParseDir(fset *token.FileSet, path string, filter func(os.FileInfo) bool, mode uint) (map[string]*ast.Package, error) {
	fd, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer fd.Close()

	list, err := fd.Readdir(-1)
	if err != nil {
		return nil, err
	}

	filenames := make([]string, len(list))
	n := 0
	for i := 0; i < len(list); i++ {
		d := list[i]
		if filter == nil || filter(d) {
			filenames[n] = filepath.Join(path, d.Name())
			n++
		}
	}
	filenames = filenames[0:n]

	return ParseFiles(fset, filenames, mode)
}
