package main

import (
	"bytes"
	"errors"
	"fmt"
	"go/ast"
	"go/token"
	"io"
	"os"
	"strconv"
	"strings"
	"text/scanner"
)

//-------------------------------------------------------------------------
// package_file_cache
//
// Structure that represents a cache for an imported pacakge. In other words
// these are the contents of an archive (*.a) file.
//-------------------------------------------------------------------------

type package_file_cache struct {
	name     string // file name
	mtime    int64
	defalias string

	scope  *scope
	main   *decl // package declaration
	others map[string]*decl
}

func new_package_file_cache(name string) *package_file_cache {
	m := new(package_file_cache)
	m.name = name
	m.mtime = 0
	m.defalias = ""
	return m
}

// Creates a cache that stays in cache forever. Useful for built-in packages.
func new_package_file_cache_forever(name, defalias string) *package_file_cache {
	m := new(package_file_cache)
	m.name = name
	m.mtime = -1
	m.defalias = defalias
	return m
}

func (m *package_file_cache) find_file() string {
	if file_exists(m.name) {
		return m.name
	}

	n := len(m.name)
	filename := m.name[:n-1] + "6"
	if file_exists(filename) {
		return filename
	}

	filename = m.name[:n-1] + "8"
	if file_exists(filename) {
		return filename
	}

	filename = m.name[:n-1] + "5"
	if file_exists(filename) {
		return filename
	}
	return m.name
}

func (m *package_file_cache) update_cache() {
	if m.mtime == -1 {
		return
	}
	fname := m.find_file()
	stat, err := os.Stat(fname)
	if err != nil {
		return
	}

	statmtime := stat.ModTime().UnixNano()
	if m.mtime != statmtime {
		m.mtime = statmtime

		data, err := file_reader.read_file(fname)
		if err != nil {
			return
		}
		m.process_package_data(data)
	}
}

func (m *package_file_cache) process_package_data(data []byte) {
	m.scope = new_scope(g_universe_scope)

	// find import section
	i := bytes.Index(data, []byte{'\n', '$', '$'})
	if i == -1 {
		panic("Can't find the import section in the package file")
	}
	data = data[i+len("\n$$"):]

	// find the beginning of the package clause
	i = bytes.Index(data, []byte{'p', 'a', 'c', 'k', 'a', 'g', 'e'})
	if i == -1 {
		panic("Can't find the package clause")
	}
	data = data[i:]

	buf := bytes.NewBuffer(data)
	var p gc_parser
	p.init(buf, m)
	// main package
	m.main = new_decl(m.name, decl_package, nil)
	// and the built-in "unsafe" package to the pathToAlias map
	p.path_to_alias["unsafe"] = "unsafe"
	// create map for other packages
	m.others = make(map[string]*decl)
	p.parse_export(func(pkg string, decl ast.Decl) {
		anonymify_ast(decl, decl_foreign, m.scope)
		if pkg == "" {
			// main package
			add_ast_decl_to_package(m.main, decl, m.scope)
		} else {
			// others
			if _, ok := m.others[pkg]; !ok {
				m.others[pkg] = new_decl(pkg, decl_package, nil)
			}
			add_ast_decl_to_package(m.others[pkg], decl, m.scope)
		}
	})

	// hack, add ourselves to the package scope
	m.add_package_to_scope("#"+m.defalias, m.name)

	// WTF is that? :D
	for key, value := range m.scope.entities {
		if strings.HasPrefix(key, "$") {
			continue
		}
		pkg, ok := m.others[value.name]
		if !ok && value.name == m.name {
			pkg = m.main
		}
		m.scope.replace_decl(key, pkg)
	}
}

func (m *package_file_cache) add_package_to_scope(alias, realname string) {
	d := new_decl(realname, decl_package, nil)
	m.scope.add_decl(alias, d)
}

func add_ast_decl_to_package(pkg *decl, decl ast.Decl, scope *scope) {
	foreach_decl(decl, func(data *foreach_decl_struct) {
		class := ast_decl_class(data.decl)
		for i, name := range data.names {
			typ, v, vi := data.type_value_index(i)

			d := new_decl_full(name.Name, class, decl_foreign, typ, v, vi, scope)
			if d == nil {
				return
			}

			if !name.IsExported() && d.class != decl_type {
				return
			}

			methodof := method_of(data.decl)
			if methodof != "" {
				decl := pkg.find_child(methodof)
				if decl != nil {
					decl.add_child(d)
				} else {
					decl = new_decl(methodof, decl_methods_stub, scope)
					decl.add_child(d)
					pkg.add_child(decl)
				}
			} else {
				decl := pkg.find_child(d.name)
				if decl != nil {
					decl.expand_or_replace(d)
				} else {
					pkg.add_child(d)
				}
			}
		}
	})
}

//-------------------------------------------------------------------------
// gc_parser
//
// The following part of the code may contain portions of the code from the Go
// standard library, which tells me to retain their copyright notice:
//
// Copyright (c) 2009 The Go Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//-------------------------------------------------------------------------

type gc_parser struct {
	scanner       scanner.Scanner
	tok           rune
	lit           string
	path_to_alias map[string]string
	beautify      bool
	pfc           *package_file_cache
}

func (p *gc_parser) init(src io.Reader, pfc *package_file_cache) {
	p.scanner.Init(src)
	p.scanner.Error = func(_ *scanner.Scanner, msg string) { p.error(msg) }
	p.scanner.Mode = scanner.ScanIdents | scanner.ScanInts | scanner.ScanStrings |
		scanner.ScanComments | scanner.ScanChars | scanner.SkipComments
	p.scanner.Whitespace = 1<<'\t' | 1<<' ' | 1<<'\r' | 1<<'\v' | 1<<'\f'
	p.scanner.Filename = "package.go"
	p.next()
	p.path_to_alias = make(map[string]string)
	p.pfc = pfc
}

func (p *gc_parser) next() {
	p.tok = p.scanner.Scan()
	switch p.tok {
	case scanner.Ident, scanner.Int, scanner.String:
		p.lit = p.scanner.TokenText()
	default:
		p.lit = ""
	}
}

func (p *gc_parser) error(msg string) {
	panic(errors.New(msg))
}

func (p *gc_parser) errorf(format string, args ...interface{}) {
	p.error(fmt.Sprintf(format, args...))
}

func (p *gc_parser) expect(tok rune) string {
	lit := p.lit
	if p.tok != tok {
		p.errorf("expected %s, got %s (%q)", scanner.TokenString(tok),
			scanner.TokenString(p.tok), lit)
	}
	p.next()
	return lit
}

func (p *gc_parser) expect_keyword(keyword string) {
	lit := p.expect(scanner.Ident)
	if lit != keyword {
		p.errorf("expected keyword: %s, got: %q", keyword, lit)
	}
}

func (p *gc_parser) expect_special(what string) {
	i := 0
	for i < len(what) {
		if p.tok != rune(what[i]) {
			break
		}

		nc := p.scanner.Peek()
		if i != len(what)-1 && nc <= ' ' {
			break
		}

		p.next()
		i++
	}

	if i < len(what) {
		p.errorf("expected: %q, got: %q", what, what[0:i])
	}
}

// dotIdentifier = "?" | ( ident | '·' ) { ident | int | '·' } .
// we're doing lexer job here, kind of
func (p *gc_parser) parse_dot_ident() string {
	if p.tok == '?' {
		p.next()
		return "?"
	}

	ident := ""
	sep := 'x'
	i, j := 0, -1
	for (p.tok == scanner.Ident || p.tok == scanner.Int || p.tok == '·') && sep > ' ' {
		ident += p.lit
		if p.tok == '·' {
			ident += "·"
			j = i
			i++
		}
		i += len(p.lit)
		sep = p.scanner.Peek()
		p.next()
	}
	// middot = \xc2\xb7
	if j != -1 && i > j+1 {
		c := ident[j+2]
		if c >= '0' && c <= '9' {
			ident = ident[0:j]
		}
	}
	return ident
}

// ImportPath = string_lit .
// quoted name of the path, but we return it as an identifier, taking an alias
// from 'pathToAlias' map, it is filled by import statements
func (p *gc_parser) parse_package() *ast.Ident {
	path, err := strconv.Unquote(p.expect(scanner.String))
	if err != nil {
		panic(err)
	}

	return ast.NewIdent(path)
}

// ExportedName = "@" ImportPath "." dotIdentifier .
func (p *gc_parser) parse_exported_name() *ast.SelectorExpr {
	p.expect('@')
	pkg := p.parse_package()
	if p.beautify {
		if pkg.Name == "" {
			pkg.Name = "#" + p.pfc.defalias
		} else {
			pkg.Name = p.path_to_alias[pkg.Name]
		}
	}
	p.expect('.')
	name := ast.NewIdent(p.parse_dot_ident())
	return &ast.SelectorExpr{X: pkg, Sel: name}
}

// Name = identifier | "?" | ExportedName .
func (p *gc_parser) parse_name() (string, ast.Expr) {
	switch p.tok {
	case scanner.Ident:
		name := p.lit
		p.next()
		return name, ast.NewIdent(name)
	case '?':
		p.next()
		return "?", ast.NewIdent("?")
	case '@':
		en := p.parse_exported_name()
		return en.Sel.Name, en
	}
	p.error("name expected")
	return "", nil
}

// Field = Name Type [ string_lit ] .
func (p *gc_parser) parse_field() *ast.Field {
	var tag string
	name, _ := p.parse_name()
	typ := p.parse_type()
	if p.tok == scanner.String {
		tag = p.expect(scanner.String)
	}

	var names []*ast.Ident
	if name != "?" {
		names = []*ast.Ident{ast.NewIdent(name)}
	}

	return &ast.Field{
		Names: names,
		Type:  typ,
		Tag:   &ast.BasicLit{Kind: token.STRING, Value: tag},
	}
}

// Parameter = ( identifier | "?" ) [ "..." ] Type [ string_lit ] .
func (p *gc_parser) parse_parameter() *ast.Field {
	// name
	name, _ := p.parse_name()

	// type
	var typ ast.Expr
	if p.tok == '.' {
		p.expect_special("...")
		typ = &ast.Ellipsis{Elt: p.parse_type()}
	} else {
		typ = p.parse_type()
	}

	var tag string
	if p.tok == scanner.String {
		tag = p.expect(scanner.String)
	}

	return &ast.Field{
		Names: []*ast.Ident{ast.NewIdent(name)},
		Type:  typ,
		Tag:   &ast.BasicLit{Kind: token.STRING, Value: tag},
	}
}

// Parameters = "(" [ ParameterList ] ")" .
// ParameterList = { Parameter "," } Parameter .
func (p *gc_parser) parse_parameters() *ast.FieldList {
	flds := []*ast.Field{}
	parse_parameter := func() {
		par := p.parse_parameter()
		flds = append(flds, par)
	}

	p.expect('(')
	if p.tok != ')' {
		parse_parameter()
		for p.tok == ',' {
			p.next()
			parse_parameter()
		}
	}
	p.expect(')')
	return &ast.FieldList{List: flds}
}

// Signature = Parameters [ Result ] .
// Result = Type | Parameters .
func (p *gc_parser) parse_signature() *ast.FuncType {
	var params *ast.FieldList
	var results *ast.FieldList

	params = p.parse_parameters()
	switch p.tok {
	case scanner.Ident, '[', '*', '<', '@':
		fld := &ast.Field{Type: p.parse_type()}
		results = &ast.FieldList{List: []*ast.Field{fld}}
	case '(':
		results = p.parse_parameters()
	}
	return &ast.FuncType{Params: params, Results: results}
}

// MethodOrEmbedSpec = Name [ Signature ] .
func (p *gc_parser) parse_method_or_embed_spec() *ast.Field {
	name, nameexpr := p.parse_name()
	if p.tok == '(' {
		typ := p.parse_signature()
		return &ast.Field{
			Names: []*ast.Ident{ast.NewIdent(name)},
			Type:  typ,
		}
	}

	return &ast.Field{
		Type: nameexpr,
	}
}

// int_lit = [ "-" | "+" ] { "0" ... "9" } .
func (p *gc_parser) parse_int() {
	switch p.tok {
	case '-', '+':
		p.next()
	}
	p.expect(scanner.Int)
}

// number = int_lit [ "p" int_lit ] .
func (p *gc_parser) parse_number() {
	p.parse_int()
	if p.lit == "p" {
		p.next()
		p.parse_int()
	}
}

//-------------------------------------------------------------------------------
// gc_parser.types
//-------------------------------------------------------------------------------

// InterfaceType = "interface" "{" [ MethodOrEmbedList ] "}" .
// MethodOrEmbedList = MethodOrEmbedSpec { ";" MethodOrEmbedSpec } .
func (p *gc_parser) parse_interface_type() ast.Expr {
	var methods []*ast.Field
	parse_method := func() {
		meth := p.parse_method_or_embed_spec()
		methods = append(methods, meth)
	}

	p.expect_keyword("interface")
	p.expect('{')
	if p.tok != '}' {
		parse_method()
		for p.tok == ';' {
			p.next()
			parse_method()
		}
	}
	p.expect('}')
	return &ast.InterfaceType{Methods: &ast.FieldList{List: methods}}
}

// StructType = "struct" "{" [ FieldList ] "}" .
// FieldList = Field { ";" Field } .
func (p *gc_parser) parse_struct_type() ast.Expr {
	var fields []*ast.Field
	parse_field := func() {
		fld := p.parse_field()
		fields = append(fields, fld)
	}

	p.expect_keyword("struct")
	p.expect('{')
	if p.tok != '}' {
		parse_field()
		for p.tok == ';' {
			p.next()
			parse_field()
		}
	}
	p.expect('}')
	return &ast.StructType{Fields: &ast.FieldList{List: fields}}
}

// MapType = "map" "[" Type "]" Type .
func (p *gc_parser) parse_map_type() ast.Expr {
	p.expect_keyword("map")
	p.expect('[')
	key := p.parse_type()
	p.expect(']')
	elt := p.parse_type()
	return &ast.MapType{Key: key, Value: elt}
}

// ChanType = ( "chan" [ "<-" ] | "<-" "chan" ) Type .
func (p *gc_parser) parse_chan_type() ast.Expr {
	dir := ast.SEND | ast.RECV
	if p.tok == scanner.Ident {
		p.expect_keyword("chan")
		if p.tok == '<' {
			p.expect_special("<-")
			dir = ast.SEND
		}
	} else {
		p.expect_special("<-")
		p.expect_keyword("chan")
		dir = ast.RECV
	}

	elt := p.parse_type()
	return &ast.ChanType{Dir: dir, Value: elt}
}

// ArrayOrSliceType = ArrayType | SliceType .
// ArrayType = "[" int_lit "]" Type .
// SliceType = "[" "]" Type .
func (p *gc_parser) parse_array_or_slice_type() ast.Expr {
	p.expect('[')
	if p.tok == ']' {
		// SliceType
		p.next() // skip ']'
		return &ast.ArrayType{Len: nil, Elt: p.parse_type()}
	}

	// ArrayType
	lit := p.expect(scanner.Int)
	p.expect(']')
	return &ast.ArrayType{
		Len: &ast.BasicLit{Kind: token.INT, Value: lit},
		Elt: p.parse_type(),
	}
}

// Type =
//	BasicType | TypeName | ArrayType | SliceType | StructType |
//      PointerType | FuncType | InterfaceType | MapType | ChanType |
//      "(" Type ")" .
// BasicType = ident .
// TypeName = ExportedName .
// SliceType = "[" "]" Type .
// PointerType = "*" Type .
// FuncType = "func" Signature .
func (p *gc_parser) parse_type() ast.Expr {
	switch p.tok {
	case scanner.Ident:
		switch p.lit {
		case "struct":
			return p.parse_struct_type()
		case "func":
			p.next()
			return p.parse_signature()
		case "interface":
			return p.parse_interface_type()
		case "map":
			return p.parse_map_type()
		case "chan":
			return p.parse_chan_type()
		default:
			lit := p.lit
			p.next()
			return ast.NewIdent(lit)
		}
	case '@':
		return p.parse_exported_name()
	case '[':
		return p.parse_array_or_slice_type()
	case '*':
		p.next()
		return &ast.StarExpr{X: p.parse_type()}
	case '<':
		return p.parse_chan_type()
	case '(':
		p.next()
		typ := p.parse_type()
		p.expect(')')
		return typ
	}
	p.errorf("unexpected token: %s", scanner.TokenString(p.tok))
	return nil
}

//-------------------------------------------------------------------------------
// gc_parser.declarations
//-------------------------------------------------------------------------------

// ImportDecl = "import" identifier string_lit .
func (p *gc_parser) parse_import_decl() {
	p.expect_keyword("import")
	alias := p.expect(scanner.Ident)
	path := p.parse_package()
	p.path_to_alias[path.Name] = alias
	p.pfc.add_package_to_scope(alias, path.Name)
}

// ConstDecl   = "const" ExportedName [ Type ] "=" Literal .
// Literal     = bool_lit | int_lit | float_lit | complex_lit | string_lit .
// bool_lit    = "true" | "false" .
// complex_lit = "(" float_lit "+" float_lit ")" .
// rune_lit    = "(" int_lit "+" int_lit ")" .
// string_lit  = `"` { unicode_char } `"` .
func (p *gc_parser) parse_const_decl() (string, *ast.GenDecl) {
	// TODO: do we really need actual const value? gocode doesn't use this
	p.expect_keyword("const")
	name := p.parse_exported_name()
	p.beautify = true

	var typ ast.Expr
	if p.tok != '=' {
		typ = p.parse_type()
	}

	p.expect('=')

	// skip the value
	switch p.tok {
	case scanner.Ident:
		// must be bool, true or false
		p.next()
	case '-', '+', scanner.Int:
		// number
		p.parse_number()
	case '(':
		// complex_lit or rune_lit
		p.next() // skip '('
		if p.tok == scanner.Char {
			p.next()
		} else {
			p.parse_number()
		}
		p.expect('+')
		p.parse_number()
		p.expect(')')
	case scanner.Char:
		p.next()
	case scanner.String:
		p.next()
	default:
		p.error("expected literal")
	}

	return name.X.(*ast.Ident).Name, &ast.GenDecl{
		Tok: token.CONST,
		Specs: []ast.Spec{
			&ast.ValueSpec{
				Names:  []*ast.Ident{name.Sel},
				Type:   typ,
				Values: []ast.Expr{&ast.BasicLit{Kind: token.INT, Value: "0"}},
			},
		},
	}
}

// TypeDecl = "type" ExportedName Type .
func (p *gc_parser) parse_type_decl() (string, *ast.GenDecl) {
	p.expect_keyword("type")
	name := p.parse_exported_name()
	p.beautify = true
	typ := p.parse_type()
	return name.X.(*ast.Ident).Name, &ast.GenDecl{
		Tok: token.TYPE,
		Specs: []ast.Spec{
			&ast.TypeSpec{
				Name: name.Sel,
				Type: typ,
			},
		},
	}
}

// VarDecl = "var" ExportedName Type .
func (p *gc_parser) parse_var_decl() (string, *ast.GenDecl) {
	p.expect_keyword("var")
	name := p.parse_exported_name()
	p.beautify = true
	typ := p.parse_type()
	return name.X.(*ast.Ident).Name, &ast.GenDecl{
		Tok: token.VAR,
		Specs: []ast.Spec{
			&ast.ValueSpec{
				Names: []*ast.Ident{name.Sel},
				Type:  typ,
			},
		},
	}
}

// FuncBody = "{" ... "}" .
func (p *gc_parser) parse_func_body() {
	p.expect('{')
	for i := 1; i > 0; p.next() {
		switch p.tok {
		case '{':
			i++
		case '}':
			i--
		}
	}
}

// FuncDecl = "func" ExportedName Signature [ FuncBody ] .
func (p *gc_parser) parse_func_decl() (string, *ast.FuncDecl) {
	// "func" was already consumed by lookahead
	name := p.parse_exported_name()
	p.beautify = true
	typ := p.parse_signature()
	if p.tok == '{' {
		p.parse_func_body()
	}
	return name.X.(*ast.Ident).Name, &ast.FuncDecl{
		Name: name.Sel,
		Type: typ,
	}
}

func strip_method_receiver(recv *ast.FieldList) string {
	var sel *ast.SelectorExpr

	// find selector expression
	typ := recv.List[0].Type
	switch t := typ.(type) {
	case *ast.StarExpr:
		sel = t.X.(*ast.SelectorExpr)
	case *ast.SelectorExpr:
		sel = t
	}

	// extract package path
	pkg := sel.X.(*ast.Ident).Name

	// write back stripped type
	switch t := typ.(type) {
	case *ast.StarExpr:
		t.X = sel.Sel
	case *ast.SelectorExpr:
		recv.List[0].Type = sel.Sel
	}

	return pkg
}

// MethodDecl = "func" Receiver Name Signature .
// Receiver = "(" ( identifier | "?" ) [ "*" ] ExportedName ")" [ FuncBody ] .
func (p *gc_parser) parse_method_decl() (string, *ast.FuncDecl) {
	recv := p.parse_parameters()
	p.beautify = true
	pkg := strip_method_receiver(recv)
	name, _ := p.parse_name()
	typ := p.parse_signature()
	if p.tok == '{' {
		p.parse_func_body()
	}
	return pkg, &ast.FuncDecl{
		Recv: recv,
		Name: ast.NewIdent(name),
		Type: typ,
	}
}

// Decl = [ ImportDecl | ConstDecl | TypeDecl | VarDecl | FuncDecl | MethodDecl ] "\n" .
func (p *gc_parser) parse_decl() (pkg string, decl ast.Decl) {
	switch p.lit {
	case "import":
		p.parse_import_decl()
	case "const":
		pkg, decl = p.parse_const_decl()
	case "type":
		pkg, decl = p.parse_type_decl()
	case "var":
		pkg, decl = p.parse_var_decl()
	case "func":
		p.next()
		if p.tok == '(' {
			pkg, decl = p.parse_method_decl()
		} else {
			pkg, decl = p.parse_func_decl()
		}
	}
	p.expect('\n')
	return
}

// Export = PackageClause { Decl } "$$" .
// PackageClause = "package" identifier [ "safe" ] "\n" .
func (p *gc_parser) parse_export(callback func(string, ast.Decl)) {
	p.expect_keyword("package")
	p.pfc.defalias = p.expect(scanner.Ident)
	if p.tok != '\n' {
		p.expect_keyword("safe")
	}
	p.expect('\n')

	for p.tok != '$' && p.tok != scanner.EOF {
		p.beautify = false
		pkg, decl := p.parse_decl()
		if decl != nil {
			callback(pkg, decl)
		}
	}
}

//-------------------------------------------------------------------------
// package_cache
//-------------------------------------------------------------------------

type package_cache map[string]*package_file_cache

func new_package_cache() package_cache {
	m := make(package_cache)

	// add built-in "unsafe" package
	m.add_builtin_unsafe_package()

	return m
}

// Function fills 'ps' set with packages from 'packages' import information.
// In case if package is not in the cache, it creates one and adds one to the cache.
func (c package_cache) append_packages(ps map[string]*package_file_cache, pkgs []package_import) {
	for _, m := range pkgs {
		if _, ok := ps[m.path]; ok {
			continue
		}

		if mod, ok := c[m.path]; ok {
			ps[m.path] = mod
		} else {
			mod = new_package_file_cache(m.path)
			ps[m.path] = mod
			c[m.path] = mod
		}
	}
}

var g_builtin_unsafe_package = []byte(`
import
$$
package unsafe
	type @"".Pointer uintptr
	func @"".Offsetof (? any) uintptr
	func @"".Sizeof (? any) uintptr
	func @"".Alignof (? any) uintptr
	func @"".Typeof (i interface { }) interface { }
	func @"".Reflect (i interface { }) (typ interface { }, addr @"".Pointer)
	func @"".Unreflect (typ interface { }, addr @"".Pointer) interface { }
	func @"".New (typ interface { }) @"".Pointer
	func @"".NewArray (typ interface { }, n int) @"".Pointer

$$
`)

func (c package_cache) add_builtin_unsafe_package() {
	pkg := new_package_file_cache_forever("unsafe", "unsafe")
	pkg.process_package_data(g_builtin_unsafe_package)
	c["unsafe"] = pkg
}
