// Types infers source locations and types from Go expressions.
// and allows enumeration of the type's method or field members.
package types

import (
	"bytes"
	"container/list"
	"fmt"
	"go/build"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/rogpeppe/godef/go/ast"
	"github.com/rogpeppe/godef/go/parser"
	"github.com/rogpeppe/godef/go/printer"
	"github.com/rogpeppe/godef/go/scanner"
	"github.com/rogpeppe/godef/go/token"
)

// Type represents the type of a Go expression.
// It can represent a Go package and a Go type as well as the
// usual expression types.
//
type Type struct {
	// Parse-tree representation of the expression's type.
	Node ast.Node

	// The kind of the expression.
	Kind ast.ObjKind

	// The path of the package that the type is relative to.
	Pkg string
}

// MultiValue represents a multiple valued Go
// expression - the result of a function that returns
// more than one value.
type MultiValue struct {
	Types []ast.Expr
}

func (MultiValue) Pos() token.Pos {
	return token.NoPos
}
func (MultiValue) End() token.Pos {
	return token.NoPos
}

var badType = Type{Kind: ast.Bad}

var makeIdent = predecl("make")
var newIdent = predecl("new")
var falseIdent = predecl("false")
var trueIdent = predecl("true")
var iotaIdent = predecl("iota")
var boolIdent = predecl("bool")
var intIdent = predecl("int")
var floatIdent = predecl("float")
var stringIdent = predecl("string")

func predecl(name string) *ast.Ident {
	return &ast.Ident{Name: name, Obj: parser.Universe.Lookup(name)}
}

type Importer func(path string) *ast.Package

// When DefaultImporter is called, it adds any files to FileSet.
var FileSet = token.NewFileSet()

// GoPath is used by DefaultImporter to find packages.
var GoPath = []string{filepath.Join(os.Getenv("GOROOT"), "src", "pkg")}

// DefaultGetPackage looks for the package; if it finds it,
// it parses and returns it. If no package was found, it returns nil.
func DefaultImporter(path string) *ast.Package {
	bpkg, err := build.Default.Import(path, "", 0)
	if err != nil {
		return nil
	}
	pkgs, err := parser.ParseDir(FileSet, bpkg.Dir, isGoFile, 0)
	if err != nil {
		if Debug {
			switch err := err.(type) {
			case scanner.ErrorList:
				for _, e := range err {
					debugp("\t%v: %s", e.Pos, e.Msg)
				}
			default:
				debugp("\terror parsing %s: %v", bpkg.Dir, err)
			}
		}
		return nil
	}
	if pkg := pkgs[bpkg.Name]; pkg != nil {
		return pkg
	}
	if Debug {
		debugp("package not found by ParseDir!")
	}
	return nil
}

// isGoFile returns true if we will consider the file as a
// possible candidate for parsing as part of a package.
// Including _test.go here isn't quite right, but what
// else can we do?
//
func isGoFile(d os.FileInfo) bool {
	return strings.HasSuffix(d.Name(), ".go") &&
		!strings.HasSuffix(d.Name(), "_test.go") &&
		!strings.HasPrefix(d.Name(), ".") &&
		goodOSArch(d.Name())
}

// When Debug is true, log messages will be printed.
var Debug = false

// String is for debugging purposes.
func (t Type) String() string {
	return fmt.Sprintf("Type{%v %q %T %v}", t.Kind, t.Pkg, t.Node, pretty{t.Node})
}

var Panic = true

// Member looks for a member with the given name inside
// the type. For packages, the member can be any exported
// top level declaration inside the package.
func (t Type) Member(name string, importer Importer) *ast.Object {
	debugp("member %v '%s' {", t, name)
	if t.Pkg != "" && !ast.IsExported(name) {
		return nil
	}
	c := make(chan *ast.Object)
	go func() {
		if !Panic {
			defer func() {
				if err := recover(); err != nil {
					log.Printf("panic: %v", err)
					c <- nil
				}
			}()
		}
		doMembers(t, name, importer, func(obj *ast.Object) {
			if obj.Name == name {
				c <- obj
				runtime.Goexit()
			}
		})
		c <- nil
	}()
	m := <-c
	debugp("} -> %v", m)
	return m
}

// Iter returns a channel, sends on it
// all the members of the type, then closes it.
// Members at a shallower depth will be
// sent first.
//
func (t Type) Iter(importer Importer) <-chan *ast.Object {
	// TODO avoid sending members with the same name twice.
	c := make(chan *ast.Object)
	go func() {
		internal := t.Pkg == ""
		doMembers(t, "", importer, func(obj *ast.Object) {
			if internal || ast.IsExported(obj.Name) {
				c <- obj
			}
		})
		close(c)
	}()
	return c
}

// ExprType returns the type for the given expression,
// and the object that represents it, if there is one.
// All variables, methods, top level functions, packages, struct and
// interface members, and types have objects.
// The returned object can be used with DeclPos to find out
// the source location of the definition of the object.
//
func ExprType(e ast.Expr, importer Importer) (obj *ast.Object, typ Type) {
	return exprType(e, false, "", importer)
}

func exprType(n ast.Node, expectTuple bool, pkg string, importer Importer) (xobj *ast.Object, typ Type) {
	debugp("exprType tuple:%v pkg:%s %T %v [", expectTuple, pkg, n, pretty{n})
	defer func() {
		debugp("] -> %p, %v", xobj, typ)
	}()
	switch n := n.(type) {
	case nil:
	case *ast.Ident:
		obj := n.Obj
		if obj == nil || obj.Kind == ast.Bad {
			break
		}
		// A type object represents itself.
		if obj.Kind == ast.Typ {
			// Objects in the universal scope don't live
			// in any package.
			if parser.Universe.Lookup(obj.Name) == obj {
				pkg = ""
			}
			return obj, Type{n, obj.Kind, pkg}
		}
		expr, typ := splitDecl(obj, n)
		switch {
		case typ != nil:
			_, t := exprType(typ, false, pkg, importer)
			if t.Kind != ast.Bad {
				t.Kind = obj.Kind
			}
			return obj, t

		case expr != nil:
			_, t := exprType(expr, false, pkg, importer)
			if t.Kind == ast.Typ {
				debugp("expected value, got type %v", t)
				t = badType
			}
			return obj, t

		default:
			switch n.Obj {
			case falseIdent.Obj, trueIdent.Obj:
				return obj, Type{boolIdent, ast.Con, ""}
			case iotaIdent.Obj:
				return obj, Type{intIdent, ast.Con, ""}
			default:
				return obj, Type{}
			}
		}
	case *ast.LabeledStmt:
		return n.Label.Obj, Type{n, ast.Lbl, pkg}

	case *ast.ImportSpec:
		return nil, Type{n, ast.Pkg, ""}

	case *ast.ParenExpr:
		return exprType(n.X, expectTuple, pkg, importer)

	case *ast.CompositeLit:
		return nil, certify(n.Type, ast.Var, pkg, importer)

	case *ast.FuncLit:
		return nil, certify(n.Type, ast.Var, pkg, importer)

	case *ast.SelectorExpr:
		_, t := exprType(n.X, false, pkg, importer)
		// TODO: method expressions. when t.Kind == ast.Typ,
		// 	mutate a method declaration into a function with
		//	the receiver as first argument
		if t.Kind == ast.Bad {
			break
		}
		obj := t.Member(n.Sel.Name, importer)
		if obj == nil {
			return nil, badType
		}
		if t.Kind == ast.Pkg {
			eobj, et := exprType(&ast.Ident{Name: obj.Name, Obj: obj}, false, t.Pkg, importer)
			et.Pkg = litToString(t.Node.(*ast.ImportSpec).Path)
			return eobj, et
		}
		// a method turns into a function type;
		// the number of formal arguments depends
		// on the class of the receiver expression.
		if fd, ismethod := obj.Decl.(*ast.FuncDecl); ismethod {
			if t.Kind == ast.Typ {
				return obj, certify(methodExpr(fd), ast.Fun, t.Pkg, importer)
			}
			return obj, certify(fd.Type, ast.Fun, t.Pkg, importer)
		} else if obj.Kind == ast.Typ {
			return obj, certify(&ast.Ident{Name: obj.Name, Obj: obj}, ast.Typ, t.Pkg, importer)
		}
		_, typ := splitDecl(obj, nil)
		return obj, certify(typ, obj.Kind, t.Pkg, importer)

	case *ast.FuncDecl:
		return nil, certify(methodExpr(n), ast.Fun, pkg, importer)

	case *ast.IndexExpr:
		_, t0 := exprType(n.X, false, pkg, importer)
		t := t0.Underlying(true, importer)
		switch n := t.Node.(type) {
		case *ast.ArrayType:
			return nil, certify(n.Elt, ast.Var, t.Pkg, importer)
		case *ast.MapType:
			t := certify(n.Value, ast.Var, t.Pkg, importer)
			if expectTuple {
				return nil, Type{MultiValue{[]ast.Expr{t.Node.(ast.Expr), predecl("bool")}}, ast.Var, t.Pkg}
			}
			return nil, t
		}

	case *ast.SliceExpr:
		_, typ := exprType(n.X, false, pkg, importer)
		return nil, typ

	case *ast.CallExpr:
		switch exprName(n.Fun) {
		case makeIdent.Obj:
			if len(n.Args) > 0 {
				return nil, certify(n.Args[0], ast.Var, pkg, importer)
			}
		case newIdent.Obj:
			if len(n.Args) > 0 {
				t := certify(n.Args[0], ast.Var, pkg, importer)
				if t.Kind != ast.Bad {
					return nil, Type{&ast.StarExpr{n.Pos(), t.Node.(ast.Expr)}, ast.Var, t.Pkg}
				}
			}
		default:
			if _, fntype := exprType(n.Fun, false, pkg, importer); fntype.Kind != ast.Bad {
				// A type cast transforms a type expression
				// into a value expression.
				if fntype.Kind == ast.Typ {
					fntype.Kind = ast.Var
					// Preserve constness if underlying expr is constant.
					if len(n.Args) == 1 {
						_, argtype := exprType(n.Args[0], false, pkg, importer)
						if argtype.Kind == ast.Con {
							fntype.Kind = ast.Con
						}
					}
					return nil, fntype
				}
				// A function call operates on the underlying type,
				t := fntype.Underlying(true, importer)
				if fn, ok := t.Node.(*ast.FuncType); ok {
					return nil, certify(fields2type(fn.Results), ast.Var, t.Pkg, importer)
				}
			}
		}

	case *ast.StarExpr:
		if _, t := exprType(n.X, false, pkg, importer); t.Kind != ast.Bad {
			if t.Kind == ast.Typ {
				return nil, Type{&ast.StarExpr{n.Pos(), t.Node.(ast.Expr)}, ast.Typ, t.Pkg}
			}
			if n, ok := t.Node.(*ast.StarExpr); ok {
				return nil, certify(n.X, ast.Var, t.Pkg, importer)
			}
		}

	case *ast.TypeAssertExpr:
		t := certify(n.Type, ast.Var, pkg, importer)
		if expectTuple && t.Kind != ast.Bad {
			return nil, Type{MultiValue{[]ast.Expr{t.Node.(ast.Expr), predecl("bool")}}, ast.Var, t.Pkg}
		}
		return nil, t

	case *ast.UnaryExpr:
		if _, t := exprType(n.X, false, pkg, importer); t.Kind != ast.Bad {
			u := t.Underlying(true, importer)
			switch n.Op {
			case token.ARROW:
				if ct, ok := u.Node.(*ast.ChanType); ok {
					t := certify(ct.Value, ast.Var, u.Pkg, importer)
					if expectTuple && t.Kind != ast.Bad {
						return nil, Type{MultiValue{[]ast.Expr{t.Node.(ast.Expr), predecl("bool")}}, ast.Var, t.Pkg}
					}
					return nil, certify(ct.Value, ast.Var, u.Pkg, importer)
				}
			case token.RANGE:
				switch n := u.Node.(type) {
				case *ast.ArrayType:
					if expectTuple {
						return nil, Type{MultiValue{[]ast.Expr{predecl("int"), n.Elt}}, ast.Var, u.Pkg}
					}

					return nil, Type{predecl("bool"), ast.Var, ""}

				case *ast.MapType:
					if expectTuple {
						return nil, Type{MultiValue{[]ast.Expr{n.Key, n.Value}}, ast.Var, u.Pkg}
					}
					return nil, certify(n.Key, ast.Var, u.Pkg, importer)

				case *ast.ChanType:
					return nil, certify(n.Value, ast.Var, u.Pkg, importer)
				}

			case token.AND:
				if t.Kind == ast.Var {
					return nil, Type{&ast.StarExpr{n.Pos(), t.Node.(ast.Expr)}, ast.Var, t.Pkg}
				}

			case token.NOT:
				return nil, Type{predecl("bool"), t.Kind, ""}

			default:
				return nil, t
			}
		}

	case *ast.BinaryExpr:
		switch n.Op {
		case token.LSS, token.EQL, token.GTR, token.NEQ, token.LEQ, token.GEQ, token.ARROW, token.LOR, token.LAND:
			_, t := exprType(n.X, false, pkg, importer)
			if t.Kind == ast.Con {
				_, t = exprType(n.Y, false, pkg, importer)
			}
			return nil, Type{predecl("bool"), t.Kind, ""}

		case token.ADD, token.SUB, token.MUL, token.QUO, token.REM, token.AND, token.AND_NOT, token.XOR:
			_, tx := exprType(n.X, false, pkg, importer)
			_, ty := exprType(n.Y, false, pkg, importer)
			switch {
			case tx.Kind == ast.Bad || ty.Kind == ast.Bad:

			case !isNamedType(tx, importer):
				return nil, ty
			case !isNamedType(ty, importer):
				return nil, tx
			}
			// could check type equality
			return nil, tx

		case token.SHL, token.SHR:
			_, typ := exprType(n.X, false, pkg, importer)
			return nil, typ
		}

	case *ast.BasicLit:
		var id *ast.Ident
		switch n.Kind {
		case token.STRING:
			id = stringIdent

		case token.INT, token.CHAR:
			id = intIdent

		case token.FLOAT:
			id = floatIdent

		default:
			debugp("unknown constant type %v", n.Kind)
		}
		if id != nil {
			return nil, Type{id, ast.Con, ""}
		}

	case *ast.StructType, *ast.ChanType, *ast.MapType, *ast.ArrayType, *ast.InterfaceType, *ast.FuncType:
		return nil, Type{n.(ast.Node), ast.Typ, pkg}

	case MultiValue:
		return nil, Type{n, ast.Typ, pkg}

	case *exprIndex:
		_, t := exprType(n.x, true, pkg, importer)
		if t.Kind != ast.Bad {
			if ts, ok := t.Node.(MultiValue); ok {
				if n.i < len(ts.Types) {
					return nil, certify(ts.Types[n.i], ast.Var, t.Pkg, importer)
				}
			}
		}
	case *ast.Ellipsis:
		t := certify(n.Elt, ast.Var, pkg, importer)
		if t.Kind != ast.Bad {
			return nil, Type{&ast.ArrayType{n.Pos(), nil, t.Node.(ast.Expr)}, ast.Var, t.Pkg}
		}

	default:
		panic(fmt.Sprintf("unknown type %T", n))
	}
	return nil, badType
}

// litToString converts from a string literal to a regular string.
func litToString(lit *ast.BasicLit) (v string) {
	if lit.Kind != token.STRING {
		panic("expected string")
	}
	v, err := strconv.Unquote(string(lit.Value))
	if err != nil {
		panic("cannot unquote")
	}
	return v
}

// doMembers iterates through a type's members, calling
// fn for each member. If name is non-empty, it looks
// directly for members with that name when possible.
// It uses the list q as a queue to perform breadth-first
// traversal, as per the Go specification.
func doMembers(typ Type, name string, importer Importer, fn func(*ast.Object)) {
	switch t := typ.Node.(type) {
	case nil:
		return

	case *ast.ImportSpec:
		path := litToString(t.Path)
		if pkg := importer(path); pkg != nil {
			doScope(pkg.Scope, name, fn, path)
		}
		return
	}

	q := list.New()
	q.PushBack(typ)
	for e := q.Front(); e != nil; e = q.Front() {
		doTypeMembers(e.Value.(Type), name, importer, fn, q)
		q.Remove(e)
	}
}

// doTypeMembers calls fn for each member of the given type,
// at one level only. Unnamed members are pushed onto the queue.
func doTypeMembers(t Type, name string, importer Importer, fn func(*ast.Object), q *list.List) {
	// strip off single indirection
	// TODO: eliminate methods disallowed when indirected.
	if u, ok := t.Node.(*ast.StarExpr); ok {
		_, t = exprType(u.X, false, t.Pkg, importer)
	}
	if id, _ := t.Node.(*ast.Ident); id != nil && id.Obj != nil {
		if scope, ok := id.Obj.Type.(*ast.Scope); ok {
			doScope(scope, name, fn, t.Pkg)
		}
	}
	u := t.Underlying(true, importer)
	switch n := u.Node.(type) {
	case *ast.StructType:
		doStructMembers(n.Fields.List, t.Pkg, importer, fn, q)

	case *ast.InterfaceType:
		doInterfaceMembers(n.Methods.List, t.Pkg, importer, fn)
	}
}

func doInterfaceMembers(fields []*ast.Field, pkg string, importer Importer, fn func(*ast.Object)) {
	// Go Spec: An interface may contain an interface type name T in place of a method
	// specification. The effect is equivalent to enumerating the methods of T explicitly
	// in the interface.

	for _, f := range fields {
		if len(f.Names) > 0 {
			for _, fname := range f.Names {
				fn(fname.Obj)
			}
		} else {
			_, typ := exprType(f.Type, false, pkg, importer)
			typ = typ.Underlying(true, importer)
			switch n := typ.Node.(type) {
			case *ast.InterfaceType:
				doInterfaceMembers(n.Methods.List, typ.Pkg, importer, fn)
			default:
				debugp("unknown anon type in interface: %T\n", n)
			}
		}
	}
}

func doStructMembers(fields []*ast.Field, pkg string, importer Importer, fn func(*ast.Object), q *list.List) {
	// Go Spec: For a value x of type T or *T where T is not an interface type, x.f
	// denotes the field or method at the shallowest depth in T where there
	// is such an f.
	// Thus we traverse shallower fields first, pushing anonymous fields
	// onto the queue for later.

	for _, f := range fields {
		if len(f.Names) > 0 {
			for _, fname := range f.Names {
				fn(fname.Obj)
			}
		} else {
			m := unnamedFieldName(f.Type)
			fn(m.Obj)
			// The unnamed field's Decl points to the
			// original type declaration.
			_, typeNode := splitDecl(m.Obj, nil)
			obj, typ := exprType(typeNode, false, pkg, importer)
			if typ.Kind == ast.Typ {
				q.PushBack(typ)
			} else {
				debugp("unnamed field kind %v (obj %v) not a type; %v", typ.Kind, obj, typ.Node)
			}
		}
	}
}

// unnamedFieldName returns the field name for
// an unnamed field with its type given by ast node t.
//
func unnamedFieldName(t ast.Node) *ast.Ident {
	switch t := t.(type) {
	case *ast.Ident:
		return t

	case *ast.SelectorExpr:
		return t.Sel

	case *ast.StarExpr:
		return unnamedFieldName(t.X)
	}

	panic("no name found for unnamed field")
}

// doScope iterates through all the functions in the given scope, at
// the top level only.
func doScope(s *ast.Scope, name string, fn func(*ast.Object), pkg string) {
	if s == nil {
		return
	}
	if name != "" {
		if obj := s.Lookup(name); obj != nil {
			fn(obj)
		}
		return
	}
	for _, obj := range s.Objects {
		if obj.Kind == ast.Bad || pkg != "" && !ast.IsExported(obj.Name) {
			continue
		}
		fn(obj)
	}
}

// If typ represents a named type, Underlying returns
// the type that it was defined as. If all is true,
// it repeats this process until the type is not
// a named type.
func (typ Type) Underlying(all bool, importer Importer) Type {
	for {
		id, _ := typ.Node.(*ast.Ident)
		if id == nil || id.Obj == nil {
			break
		}
		_, typNode := splitDecl(id.Obj, id)
		_, t := exprType(typNode, false, typ.Pkg, importer)
		if t.Kind != ast.Typ {
			return badType
		}
		typ.Node = t.Node
		typ.Pkg = t.Pkg
		if !all {
			break
		}
	}
	return typ
}

func noParens(typ interface{}) interface{} {
	for {
		if n, ok := typ.(*ast.ParenExpr); ok {
			typ = n.X
		} else {
			break
		}
	}
	return typ
}

// make sure that the type is really a type expression
func certify(typ ast.Node, kind ast.ObjKind, pkg string, importer Importer) Type {
	_, t := exprType(typ, false, pkg, importer)
	if t.Kind == ast.Typ {
		return Type{t.Node, kind, t.Pkg}
	}
	return badType
}

// If n represents a single identifier, exprName returns its object.
func exprName(typ interface{}) *ast.Object {
	switch t := noParens(typ).(type) {
	case *ast.Ident:
		return t.Obj
	case *ast.Object:
		return t
	}
	return nil
}

// exprIndex represents the selection of one member
// of a multiple-value expression, as in
// _, err := fd.Read(...)
type exprIndex struct {
	i int
	x ast.Expr
}

func (e *exprIndex) Pos() token.Pos {
	return token.NoPos
}
func (e *exprIndex) End() token.Pos {
	return token.NoPos
}

// splitDecl splits obj.Decl and returns the expression part and the type part.
// Either may be nil, but not both if the declaration is value.
//
// If id is non-nil, it gives the referring identifier. This is only used
// to determine which node in a type switch is being referred to.
//
func splitDecl(obj *ast.Object, id *ast.Ident) (expr, typ ast.Node) {
	switch decl := obj.Decl.(type) {
	case nil:
		return nil, nil
	case *ast.ValueSpec:
		return splitVarDecl(obj.Name, decl.Names, decl.Values, decl.Type)

	case *ast.TypeSpec:
		return nil, decl.Type

	case *ast.FuncDecl:
		if decl.Recv != nil {
			return decl, decl.Type
		}
		return decl.Body, decl.Type

	case *ast.Field:
		return nil, decl.Type

	case *ast.LabeledStmt:
		return decl, nil

	case *ast.ImportSpec:
		return nil, decl

	case *ast.AssignStmt:
		return splitVarDecl(obj.Name, exprsToIdents(decl.Lhs), decl.Rhs, nil)

	case *ast.GenDecl:
		if decl.Tok == token.CONST {
			return splitConstDecl(obj.Name, decl)
		}
	case *ast.TypeSwitchStmt:
		expr := decl.Assign.(*ast.AssignStmt).Rhs[0].(*ast.TypeAssertExpr).X
		for _, stmt := range decl.Body.List {
			tcase := stmt.(*ast.CaseClause)
			for _, stmt := range tcase.Body {
				if containsNode(stmt, id) {
					if len(tcase.List) == 1 {
						return expr, tcase.List[0]
					}
					return expr, nil
				}
			}
		}
		return expr, nil
	}
	debugp("unknown decl type %T %v", obj.Decl, pretty{obj.Decl})
	return nil, nil
}

// splitVarDecl finds the declaration expression and type from a
// variable declaration (short form or long form).
func splitVarDecl(name string, names []*ast.Ident, values []ast.Expr, vtype ast.Expr) (expr, typ ast.Node) {
	if len(names) == 1 && len(values) == 1 {
		return values[0], vtype
	}
	p := 0
	for i, aname := range names {
		if aname != nil && aname.Name == name {
			p = i
			break
		}
	}
	if len(values) > 1 {
		return values[p], vtype
	}
	if len(values) == 0 {
		return nil, vtype
	}
	return &exprIndex{p, values[0]}, vtype
}

func exprsToIdents(exprs []ast.Expr) []*ast.Ident {
	idents := make([]*ast.Ident, len(exprs))
	for i, e := range exprs {
		idents[i], _ = e.(*ast.Ident)
	}
	return idents
}

// Constant declarations can omit the type, so the declaration for
// a const may be the entire GenDecl - we find the relevant
// clause and infer the type and expression.
func splitConstDecl(name string, decl *ast.GenDecl) (expr, typ ast.Node) {
	var lastSpec *ast.ValueSpec // last spec with >0 values.
	for _, spec := range decl.Specs {
		vspec := spec.(*ast.ValueSpec)
		if len(vspec.Values) > 0 {
			lastSpec = vspec
		}
		for i, vname := range vspec.Names {
			if vname.Name == name {
				if i < len(lastSpec.Values) {
					return lastSpec.Values[i], lastSpec.Type
				}
				return nil, lastSpec.Type
			}
		}
	}
	return nil, nil
}

// funcVisitor allows an ast.Visitor to be implemented
// by a single function.
type funcVisitor func(n ast.Node) bool

func (f funcVisitor) Visit(n ast.Node) ast.Visitor {
	if f(n) {
		return f
	}
	return nil
}

// constainsNode returns true if x is found somewhere
// inside node.
func containsNode(node, x ast.Node) (found bool) {
	ast.Walk(funcVisitor(func(n ast.Node) bool {
		if !found {
			found = n == x
		}
		return !found
	}),
		node)
	return
}

func isNamedType(typ Type, importer Importer) bool {
	return typ.Underlying(false, importer).Node != typ.Node
}

func fields2type(fields *ast.FieldList) ast.Node {
	if fields == nil {
		return MultiValue{nil}
	}
	n := 0
	for _, f := range fields.List {
		j := len(f.Names)
		if j == 0 {
			j = 1
		}
		n += j
	}
	switch n {
	case 0:
		return nil
	case 1:
		return fields.List[0].Type
	}
	elist := make([]ast.Expr, n)
	i := 0
	for _, f := range fields.List {
		j := len(f.Names)
		if j == 0 {
			j = 1
		}
		for ; j > 0; j-- {
			elist[i] = f.Type
			i++
		}
	}
	return MultiValue{elist}
}

// TODO
func methodExpr(fd *ast.FuncDecl) *ast.FuncType {
	return fd.Type
}

// XXX  the following stuff is for debugging - remove later.

func debugp(f string, a ...interface{}) {
	if Debug {
		log.Printf(f, a...)
	}
}

type pretty struct {
	n interface{}
}

func (p pretty) String() string {
	var b bytes.Buffer
	printer.Fprint(&b, FileSet, p.n)
	return b.String()
}
