package types

import (
	"bytes"
	"flag"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"unicode"

	"github.com/rogpeppe/godef/go/ast"
	"github.com/rogpeppe/godef/go/parser"
	"github.com/rogpeppe/godef/go/token"
)

var testStdlib = flag.Bool("test-stdlib", false, "test all symbols in standard library (will fail)")

// TODO recursive types avoiding infinite loop.
// e.g.
// type A struct {*A}
// func (a *A) Foo() {
// }
// var x *A

type astVisitor func(n ast.Node) bool

func (f astVisitor) Visit(n ast.Node) ast.Visitor {
	if f(n) {
		return f
	}
	return nil
}

func parseDir(dir string) *ast.Package {
	pkgs, _ := parser.ParseDir(FileSet, dir, isGoFile, 0)
	if len(pkgs) == 0 {
		return nil
	}
	delete(pkgs, "documentation")
	for name, pkg := range pkgs {
		if len(pkgs) == 1 || name != "main" {
			return pkg
		}
	}
	return nil
}

func checkExprs(t *testing.T, pkg *ast.File, importer Importer) {
	var visit astVisitor
	stopped := false
	visit = func(n ast.Node) bool {
		if stopped {
			return false
		}
		mustResolve := false
		var e ast.Expr
		switch n := n.(type) {
		case *ast.ImportSpec:
			// If the file imports a package to ".", abort
			// because we don't support that (yet).
			if n.Name != nil && n.Name.Name == "." {
				stopped = true
				return false
			}
			return true

		case *ast.FuncDecl:
			// add object for init functions
			if n.Recv == nil && n.Name.Name == "init" {
				n.Name.Obj = ast.NewObj(ast.Fun, "init")
			}
			return true

		case *ast.Ident:
			if n.Name == "_" {
				return false
			}
			e = n
			mustResolve = true

		case *ast.KeyValueExpr:
			// don't try to resolve the key part of a key-value
			// because it might be a map key which doesn't
			// need resolving, and we can't tell without being
			// complicated with types.
			ast.Walk(visit, n.Value)
			return false

		case *ast.SelectorExpr:
			ast.Walk(visit, n.X)
			e = n
			mustResolve = true

		case *ast.File:
			for _, d := range n.Decls {
				ast.Walk(visit, d)
			}
			return false

		case ast.Expr:
			e = n

		default:
			return true
		}
		defer func() {
			if err := recover(); err != nil {
				t.Fatalf("panic (%v) on %T", err, e)
				//t.Fatalf("panic (%v) on %v at %v\n", err, e, FileSet.Position(e.Pos()))
			}
		}()
		obj, _ := ExprType(e, importer)
		if obj == nil && mustResolve {
			t.Errorf("no object for %v(%p, %T) at %v\n", e, e, e, FileSet.Position(e.Pos()))
		}
		return false
	}
	ast.Walk(visit, pkg)
}

func TestStdLib(t *testing.T) {
	if !*testStdlib {
		t.SkipNow()
	}
	Panic = false
	defer func() {
		Panic = true
	}()
	root := os.Getenv("GOROOT") + "/src"
	cache := make(map[string]*ast.Package)
	importer := func(path string) *ast.Package {
		p := filepath.Join(root, "pkg", path)
		if pkg := cache[p]; pkg != nil {
			return pkg
		}
		pkg := DefaultImporter(path)
		cache[p] = pkg
		return pkg
	}
	//	excluded := map[string]bool{
	//		filepath.Join(root, "pkg/exp/wingui"): true,
	//	}
	visit := func(path string, f os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !f.IsDir() {
			return nil
		}
		pkg := cache[path]
		if pkg == nil {
			pkg = parseDir(path)
		}
		if pkg != nil {
			for _, f := range pkg.Files {
				checkExprs(t, f, importer)
			}
		}
		return nil
	}

	filepath.Walk(root, visit)
}

// TestCompile writes the test code to /tmp/testcode.go so
// that it can be verified that it actually compiles.
func TestCompile(t *testing.T) {
	return // avoid usually
	code, _ := translateSymbols(testCode)
	err := ioutil.WriteFile("/tmp/testcode.go", code, 0666)
	if err != nil {
		t.Errorf("write file failed: %v", err)
	}
}

func TestOneFile(t *testing.T) {
	code, offsetMap := translateSymbols(testCode)
	//fmt.Printf("------------------- {%s}\n", code)
	f, err := parser.ParseFile(FileSet, "xx.go", code, 0, ast.NewScope(parser.Universe))
	if err != nil {
		t.Fatalf("parse failed: %v", err)
	}
	v := make(identVisitor)
	go func() {
		ast.Walk(v, f)
		close(v)
	}()
	for e := range v {
		testExpr(t, FileSet, e, offsetMap)
	}
}

func testExpr(t *testing.T, fset *token.FileSet, e ast.Expr, offsetMap map[int]*sym) {
	var name *ast.Ident
	switch e := e.(type) {
	case *ast.SelectorExpr:
		name = e.Sel
	case *ast.Ident:
		name = e
	default:
		panic("unexpected expression type")
	}
	from := fset.Position(name.NamePos)
	obj, typ := ExprType(e, DefaultImporter)
	if obj == nil {
		t.Errorf("no object found for %v at %v", pretty{e}, from)
		return
	}
	if typ.Kind == ast.Bad {
		t.Errorf("no type found for %v at %v", pretty{e}, from)
		return
	}
	if name.Name != obj.Name {
		t.Errorf("wrong name found for %v at %v; expected %q got %q", pretty{e}, from, name, obj.Name)
		return
	}
	to := offsetMap[from.Offset]
	if to == nil {
		t.Errorf("no source symbol entered for %s at %v", name.Name, from)
		return
	}
	found := fset.Position(DeclPos(obj))
	if found.Offset != to.offset {
		t.Errorf("wrong offset found for %v at %v, decl %T (%#v); expected %d got %d", pretty{e}, from, obj.Decl, obj.Decl, to.offset, found.Offset)
	}
	if typ.Kind != to.kind {
		t.Errorf("wrong type for %s at %v; expected %v got %v", name.Name, from, to.kind, typ.Kind)
	}
}

type identVisitor chan ast.Expr

func (v identVisitor) Visit(n ast.Node) ast.Visitor {
	switch n := n.(type) {
	case *ast.Ident:
		if strings.HasPrefix(n.Name, prefix) {
			v <- n
		}
		return nil
	case *ast.SelectorExpr:
		ast.Walk(v, n.X)
		if strings.HasPrefix(n.Sel.Name, prefix) {
			v <- n
		}
		return nil
	}
	return v
}

const prefix = "xx"

var kinds = map[rune]ast.ObjKind{
	'v': ast.Var,
	'c': ast.Con,
	't': ast.Typ,
	'f': ast.Fun,
	'l': ast.Lbl,
}

type sym struct {
	name   string
	offset int
	kind   ast.ObjKind
}

// transateSymbols performs a non-parsing translation of some Go source
// code. For each symbol starting with xx, it returns an entry in
// offsetMap mapping from the reference in the source code to the first
// occurrence of that symbol. If the symbol is followed by #x, it refers
// to a particular version of the symbol. The translated code will
// produce only the bare symbol, but the expected symbol can be
// determined from the returned map.
//
// The first occurrence of a translated symbol must be followed by a @
// and letter representing the symbol kind (see kinds, above). All
// subsequent references to that symbol must resolve to the given kind.
//
func translateSymbols(code []byte) (result []byte, offsetMap map[int]*sym) {
	offsetMap = make(map[int]*sym)
	buf := bytes.NewBuffer(code)
	syms := make(map[string]*sym)
	var wbuf, sbuf bytes.Buffer
	for {
		r, _, err := buf.ReadRune()
		if err != nil {
			break
		}
		if r != rune(prefix[0]) {
			wbuf.WriteRune(r)
			continue
		}
		sbuf.Reset()
		for unicode.IsLetter(r) || unicode.IsDigit(r) || r == '_' || r == '#' {
			sbuf.WriteRune(r)
			r, _, err = buf.ReadRune()
			if err != nil {
				break
			}
		}
		var typec rune
		if r == '@' {
			typec, _, err = buf.ReadRune()
		} else {
			buf.UnreadRune()
		}
		name := sbuf.String()
		if !strings.HasPrefix(name, prefix) {
			sbuf.WriteString(name)
			continue
		}
		bareName := name
		if i := strings.IndexRune(bareName, '#'); i >= 0 {
			bareName = bareName[:i]
		}
		s := syms[name]
		if s == nil {
			if typec == 0 {
				panic("missing type character for symbol: " + name)
			}
			s = &sym{name, wbuf.Len(), kinds[typec]}
			if s.kind == ast.Bad {
				panic("bad type character " + string(typec))
			}
			syms[name] = s
		}
		offsetMap[wbuf.Len()] = s
		wbuf.WriteString(bareName)
	}
	result = wbuf.Bytes()
	return
}

var testCode = []byte(
	`package main

import "os"

type xx_struct@t struct {
	xx_1@v int
	xx_2@v int
}

type xx_link@t struct {
	xx_3@v    int
	xx_next@v *xx_link
}

type xx_structEmbed@t struct {
	xx_struct#f@v
}

type xx_interface@t interface {
	xx_value#i@f()
}

type xx_interfaceAndMethod#t@t interface {
	xx_interfaceAndMethod#i@f()
}

type xx_interfaceEmbed@t interface {
	xx_interface
	xx_interfaceAndMethod#t
}

type xx_int@t int

func (xx_int) xx_k@f() {}

const (
	xx_inta@c, xx_int1@c = xx_int(iota), xx_int(iota * 2)
	xx_intb@c, xx_int2@c
	xx_intc@c, xx_int3@c
)

var fd1 = os.Stdin

func (xx_4@v *xx_struct) xx_ptr@f()  {
	_ = xx_4.xx_1
}
func (xx_5@v xx_struct) xx_value#s@f() {
	_ = xx_5.xx_2
}

func (s xx_structEmbed) xx_value#e@f() {}

type xx_other@t bool
func (xx_other) xx_value#x@f() {}

var xxv_int@v xx_int

var xx_chan@v chan xx_struct
var xx_map@v map[string]xx_struct
var xx_slice@v []xx_int

var (
	xx_func@v func() xx_struct
	xx_mvfunc@v func() (string, xx_struct, xx_struct)
	xxv_interface@v interface{}
)
var xxv_link@v *xx_link

func xx_foo@f(xx_int) xx_int {
	return 0
}

func main() {

	fd := os.NewFile(1, "/dev/stdout")
	_, _ = fd.Write(nil)
	fd1.Write(nil)

	_ = (<-xx_chan).xx_1
	xx_structv@v := <-xx_chan
	_ = xx_struct
	tmp, _ := <-xx_chan
	_ = tmp.xx_1

	_ = xx_map[""].xx_1
	_ = xx_slice[xxv_int:xxv_int:xxv_int]

	xx_a2@v, _ := xx_map[""]
	_ = xx_a2.xx_2

	_ = xx_func().xx_1

	xx_c@v, xx_d@v, xx_e@v := xx_mvfunc()
	_ = xx_d.xx_2
	_ = xx_e.xx_1

	xx_f@v := func() xx_struct { return xx_struct{} }
	_ = xx_f().xx_2

	xx_g@v := xxv_interface.(xx_struct).xx_1
	xx_h@v, _ := xxv_interface.(xx_struct)
	_ = xx_h.xx_2

	var xx_6@v xx_interface = xx_struct{}

	switch xx_i@v := xx_6.(type) {
	case xx_struct, xx_structEmbed:
		xx_i.xx_value#i()
	case xx_interface:
		xx_i.xx_value#i()
	case xx_other:
		xx_i.xx_value#x()
	}
	var xx_iembed@v xx_interfaceEmbed
	xx_iembed.xx_value#i()
	xx_iembed.xx_interfaceAndMethod#i()


	xx_map2@v := make(map[xx_int]xx_struct)
	for xx_a@v, xx_b@v := range xx_map2 {
		xx_a.xx_k()
		_ = xx_b.xx_2
	}
	for xx_a3@v := range xx_map2 {
		xx_a3.xx_k()
	}

	for xx_a4@v := range xx_chan {
		_ = xx_a4.xx_1
	}

	xxv_struct@v := new(xx_struct)
	_ = xxv_struct.xx_1

	var xx_1e@v xx_structEmbed
	xx_1e.xx_value#e()
	xx_1e.xx_ptr()
	_ = xx_1e.xx_struct#f

	var xx_2e@v xx_struct
	xx_2e.xx_value#s()
	xx_2e.xx_ptr()

	xxv_int.xx_k()
	xx_inta.xx_k()
	xx_intb.xx_k()
	xx_intc.xx_k()
	xx_int1.xx_k()
	xx_int2.xx_k()
	xx_int3.xx_k()

	xxa@v := []xx_int{1, 2, 3}
	xxa[0].xx_k()

	xxp@v := new(int)
	(*xx_int)(xxp).xx_k()
	var xx_label#v@v xx_struct

xx_label#l@l:
	xx_foo(5).xx_k()

	goto xx_label#l
	_ = xx_label#v.xx_1

	_ = xxv_link.xx_next.xx_next.xx_3

	type xx_internalType@t struct {
		xx_7@v xx_struct
	}
	xx_intern@v := xx_internalType{}
	_ = xx_intern.xx_7.xx_1

	use(xx_c, xx_d, xx_e, xx_f, xx_g, xx_h)
}


func xx_varargs@f(xx_args@v ... xx_struct) {
	_ = xx_args[0].xx_1
}

func use(...interface{}) {}
`)
