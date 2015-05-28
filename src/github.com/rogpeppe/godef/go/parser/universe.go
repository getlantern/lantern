package parser

import "github.com/rogpeppe/godef/go/ast"

var Universe = ast.NewScope(nil)

func declObj(kind ast.ObjKind, name string) {
	// don't use Insert because it forbids adding to Universe
	Universe.Objects[name] = ast.NewObj(kind, name)
}

func init() {
	declObj(ast.Typ, "bool")

	declObj(ast.Typ, "complex64")
	declObj(ast.Typ, "complex128")

	declObj(ast.Typ, "int")
	declObj(ast.Typ, "int8")
	declObj(ast.Typ, "int16")
	declObj(ast.Typ, "int32")
	declObj(ast.Typ, "int64")

	declObj(ast.Typ, "uint")
	declObj(ast.Typ, "uintptr")
	declObj(ast.Typ, "uint8")
	declObj(ast.Typ, "uint16")
	declObj(ast.Typ, "uint32")
	declObj(ast.Typ, "uint64")

	declObj(ast.Typ, "float")
	declObj(ast.Typ, "float32")
	declObj(ast.Typ, "float64")

	declObj(ast.Typ, "string")
	declObj(ast.Typ, "error")

	// predeclared constants
	// TODO(gri) provide constant value
	declObj(ast.Con, "false")
	declObj(ast.Con, "true")
	declObj(ast.Con, "iota")
	declObj(ast.Con, "nil")

	// predeclared functions
	// TODO(gri) provide "type"
	declObj(ast.Fun, "append")
	declObj(ast.Fun, "cap")
	declObj(ast.Fun, "close")
	declObj(ast.Fun, "complex")
	declObj(ast.Fun, "copy")
	declObj(ast.Fun, "delete")
	declObj(ast.Fun, "imag")
	declObj(ast.Fun, "len")
	declObj(ast.Fun, "make")
	declObj(ast.Fun, "new")
	declObj(ast.Fun, "panic")
	declObj(ast.Fun, "panicln")
	declObj(ast.Fun, "print")
	declObj(ast.Fun, "println")
	declObj(ast.Fun, "real")
	declObj(ast.Fun, "recover")

	// byte is an alias for uint8, so cheat
	// by storing the same object for both name
	// entries
	Universe.Objects["byte"] = Universe.Objects["uint8"]

	// The same applies to rune.
	Universe.Objects["rune"] = Universe.Objects["uint32"]
}
