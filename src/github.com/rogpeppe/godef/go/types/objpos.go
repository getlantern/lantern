package types

import (
	"github.com/rogpeppe/godef/go/ast"
	"github.com/rogpeppe/godef/go/token"
)

func declPos(name string, decl ast.Node) token.Pos {
	switch d := decl.(type) {
	case nil:
		return token.NoPos
	case *ast.AssignStmt:
		for _, n := range d.Lhs {
			if n, ok := n.(*ast.Ident); ok && n.Name == name {
				return n.Pos()
			}
		}
	case *ast.Field:
		for _, n := range d.Names {
			if n.Name == name {
				return n.Pos()
			}
		}
	case *ast.ValueSpec:
		for _, n := range d.Names {
			if n.Name == name {
				return n.Pos()
			}
		}
	case *ast.TypeSpec:
		if d.Name.Name == name {
			return d.Name.Pos()
		}
	case *ast.FuncDecl:
		if d.Name.Name == name {
			return d.Name.Pos()
		}
	case *ast.LabeledStmt:
		if d.Label.Name == name {
			return d.Label.Pos()
		}
	case *ast.GenDecl:
		for _, spec := range d.Specs {
			if pos := declPos(name, spec); pos.IsValid() {
				return pos
			}
		}
	case *ast.TypeSwitchStmt:
		return declPos(name, d.Assign)
	}
	return token.NoPos
}

// DeclPos computes the source position of the declaration of an object name.
// The result may be an invalid position if it cannot be computed
// (obj.Decl may be nil or not correct).
// This should be called ast.Object.Pos.
func DeclPos(obj *ast.Object) token.Pos {
	decl, _ := obj.Decl.(ast.Node)
	if decl == nil {
		return token.NoPos
	}
	pos := declPos(obj.Name, decl)
	if !pos.IsValid() {
		pos = decl.Pos()
	}
	return pos
}
