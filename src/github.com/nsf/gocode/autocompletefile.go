package main

import (
	"bytes"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"log"
)

func parse_decl_list(fset *token.FileSet, data []byte) ([]ast.Decl, error) {
	var buf bytes.Buffer
	buf.WriteString("package p;")
	buf.Write(data)
	file, err := parser.ParseFile(fset, "", buf.Bytes(), 0)
	if err != nil {
		return file.Decls, err
	}
	return file.Decls, nil
}

//-------------------------------------------------------------------------
// auto_complete_file
//-------------------------------------------------------------------------

type auto_complete_file struct {
	name         string
	package_name string

	decls     map[string]*decl
	packages  []package_import
	filescope *scope
	scope     *scope

	cursor  int // for current file buffer only
	fset    *token.FileSet
	context build.Context
}

func new_auto_complete_file(name string, context build.Context) *auto_complete_file {
	p := new(auto_complete_file)
	p.name = name
	p.cursor = -1
	p.fset = token.NewFileSet()
	p.context = context
	return p
}

func (f *auto_complete_file) offset(p token.Pos) int {
	const fixlen = len("package p;")
	return f.fset.Position(p).Offset - fixlen
}

// this one is used for current file buffer exclusively
func (f *auto_complete_file) process_data(data []byte) {
	cur, filedata, block := rip_off_decl(data, f.cursor)
	file, err := parser.ParseFile(f.fset, "", filedata, 0)
	if err != nil && *g_debug {
		log.Printf("Error parsing input file: %s", err)
	}
	f.package_name = package_name(file)

	f.decls = make(map[string]*decl)
	f.packages = collect_package_imports(f.name, file.Decls, f.context)
	f.filescope = new_scope(nil)
	f.scope = f.filescope

	for _, d := range file.Decls {
		anonymify_ast(d, 0, f.filescope)
	}

	// process all top-level declarations
	for _, decl := range file.Decls {
		append_to_top_decls(f.decls, decl, f.scope)
	}
	if block != nil {
		// process local function as top-level declaration
		decls, _ := parse_decl_list(f.fset, block)

		for _, d := range decls {
			anonymify_ast(d, 0, f.filescope)
		}

		for _, decl := range decls {
			append_to_top_decls(f.decls, decl, f.scope)
		}

		// process function internals
		f.cursor = cur
		for _, decl := range decls {
			f.process_decl_locals(decl)
		}
	}

}

func (f *auto_complete_file) process_decl_locals(decl ast.Decl) {
	switch t := decl.(type) {
	case *ast.FuncDecl:
		if f.cursor_in(t.Body) {
			s := f.scope
			f.scope = new_scope(f.scope)

			f.process_field_list(t.Recv, s)
			f.process_field_list(t.Type.Params, s)
			f.process_field_list(t.Type.Results, s)
			f.process_block_stmt(t.Body)

		}
	default:
		v := new(func_lit_visitor)
		v.ctx = f
		ast.Walk(v, decl)
	}
}

func (f *auto_complete_file) process_decl(decl ast.Decl) {
	if t, ok := decl.(*ast.GenDecl); ok && f.offset(t.TokPos) > f.cursor {
		return
	}
	prevscope := f.scope
	foreach_decl(decl, func(data *foreach_decl_struct) {
		class := ast_decl_class(data.decl)
		if class != decl_type {
			f.scope, prevscope = advance_scope(f.scope)
		}
		for i, name := range data.names {
			typ, v, vi := data.type_value_index(i)

			d := new_decl_full(name.Name, class, 0, typ, v, vi, prevscope)
			if d == nil {
				return
			}

			f.scope.add_named_decl(d)
		}
	})
}

func (f *auto_complete_file) process_block_stmt(block *ast.BlockStmt) {
	if block != nil && f.cursor_in(block) {
		f.scope, _ = advance_scope(f.scope)

		for _, stmt := range block.List {
			f.process_stmt(stmt)
		}

		// hack to process all func literals
		v := new(func_lit_visitor)
		v.ctx = f
		ast.Walk(v, block)
	}
}

type func_lit_visitor struct {
	ctx *auto_complete_file
}

func (v *func_lit_visitor) Visit(node ast.Node) ast.Visitor {
	if t, ok := node.(*ast.FuncLit); ok && v.ctx.cursor_in(t.Body) {
		s := v.ctx.scope
		v.ctx.scope = new_scope(v.ctx.scope)

		v.ctx.process_field_list(t.Type.Params, s)
		v.ctx.process_field_list(t.Type.Results, s)
		v.ctx.process_block_stmt(t.Body)

		return nil
	}
	return v
}

func (f *auto_complete_file) process_stmt(stmt ast.Stmt) {
	switch t := stmt.(type) {
	case *ast.DeclStmt:
		f.process_decl(t.Decl)
	case *ast.AssignStmt:
		f.process_assign_stmt(t)
	case *ast.IfStmt:
		if f.cursor_in_if_head(t) {
			f.process_stmt(t.Init)
		} else if f.cursor_in_if_stmt(t) {
			f.scope, _ = advance_scope(f.scope)
			f.process_stmt(t.Init)
			f.process_block_stmt(t.Body)
			f.process_stmt(t.Else)
		}
	case *ast.BlockStmt:
		f.process_block_stmt(t)
	case *ast.RangeStmt:
		f.process_range_stmt(t)
	case *ast.ForStmt:
		if f.cursor_in_for_head(t) {
			f.process_stmt(t.Init)
		} else if f.cursor_in(t.Body) {
			f.scope, _ = advance_scope(f.scope)

			f.process_stmt(t.Init)
			f.process_block_stmt(t.Body)
		}
	case *ast.SwitchStmt:
		f.process_switch_stmt(t)
	case *ast.TypeSwitchStmt:
		f.process_type_switch_stmt(t)
	case *ast.SelectStmt:
		f.process_select_stmt(t)
	case *ast.LabeledStmt:
		f.process_stmt(t.Stmt)
	}
}

func (f *auto_complete_file) process_select_stmt(a *ast.SelectStmt) {
	if !f.cursor_in(a.Body) {
		return
	}
	var prevscope *scope
	f.scope, prevscope = advance_scope(f.scope)

	var last_cursor_after *ast.CommClause
	for _, s := range a.Body.List {
		if cc := s.(*ast.CommClause); f.cursor > f.offset(cc.Colon) {
			last_cursor_after = cc
		}
	}

	if last_cursor_after != nil {
		if last_cursor_after.Comm != nil {
			//if lastCursorAfter.Lhs != nil && lastCursorAfter.Tok == token.DEFINE {
			if astmt, ok := last_cursor_after.Comm.(*ast.AssignStmt); ok && astmt.Tok == token.DEFINE {
				vname := astmt.Lhs[0].(*ast.Ident).Name
				v := new_decl_var(vname, nil, astmt.Rhs[0], -1, prevscope)
				f.scope.add_named_decl(v)
			}
		}
		for _, s := range last_cursor_after.Body {
			f.process_stmt(s)
		}
	}
}

func (f *auto_complete_file) process_type_switch_stmt(a *ast.TypeSwitchStmt) {
	if !f.cursor_in(a.Body) {
		return
	}
	var prevscope *scope
	f.scope, prevscope = advance_scope(f.scope)

	f.process_stmt(a.Init)
	// type var
	var tv *decl
	if a, ok := a.Assign.(*ast.AssignStmt); ok {
		lhs := a.Lhs
		rhs := a.Rhs
		if lhs != nil && len(lhs) == 1 {
			tvname := lhs[0].(*ast.Ident).Name
			tv = new_decl_var(tvname, nil, rhs[0], -1, prevscope)
		}
	}

	var last_cursor_after *ast.CaseClause
	for _, s := range a.Body.List {
		if cc := s.(*ast.CaseClause); f.cursor > f.offset(cc.Colon) {
			last_cursor_after = cc
		}
	}

	if last_cursor_after != nil {
		if tv != nil {
			if last_cursor_after.List != nil && len(last_cursor_after.List) == 1 {
				tv.typ = last_cursor_after.List[0]
				tv.value = nil
			}
			f.scope.add_named_decl(tv)
		}
		for _, s := range last_cursor_after.Body {
			f.process_stmt(s)
		}
	}
}

func (f *auto_complete_file) process_switch_stmt(a *ast.SwitchStmt) {
	if !f.cursor_in(a.Body) {
		return
	}
	f.scope, _ = advance_scope(f.scope)

	f.process_stmt(a.Init)
	var last_cursor_after *ast.CaseClause
	for _, s := range a.Body.List {
		if cc := s.(*ast.CaseClause); f.cursor > f.offset(cc.Colon) {
			last_cursor_after = cc
		}
	}
	if last_cursor_after != nil {
		for _, s := range last_cursor_after.Body {
			f.process_stmt(s)
		}
	}
}

func (f *auto_complete_file) process_range_stmt(a *ast.RangeStmt) {
	if !f.cursor_in(a.Body) {
		return
	}
	var prevscope *scope
	f.scope, prevscope = advance_scope(f.scope)

	if a.Tok == token.DEFINE {
		if t, ok := a.Key.(*ast.Ident); ok {
			d := new_decl_var(t.Name, nil, a.X, 0, prevscope)
			if d != nil {
				d.flags |= decl_rangevar
				f.scope.add_named_decl(d)
			}
		}

		if a.Value != nil {
			if t, ok := a.Value.(*ast.Ident); ok {
				d := new_decl_var(t.Name, nil, a.X, 1, prevscope)
				if d != nil {
					d.flags |= decl_rangevar
					f.scope.add_named_decl(d)
				}
			}
		}
	}

	f.process_block_stmt(a.Body)
}

func (f *auto_complete_file) process_assign_stmt(a *ast.AssignStmt) {
	if a.Tok != token.DEFINE || f.offset(a.TokPos) > f.cursor {
		return
	}

	names := make([]*ast.Ident, len(a.Lhs))
	for i, name := range a.Lhs {
		id, ok := name.(*ast.Ident)
		if !ok {
			// something is wrong, just ignore the whole stmt
			return
		}
		names[i] = id
	}

	var prevscope *scope
	f.scope, prevscope = advance_scope(f.scope)

	pack := decl_pack{names, nil, a.Rhs}
	for i, name := range pack.names {
		typ, v, vi := pack.type_value_index(i)
		d := new_decl_var(name.Name, typ, v, vi, prevscope)
		if d == nil {
			continue
		}

		f.scope.add_named_decl(d)
	}
}

func (f *auto_complete_file) process_field_list(field_list *ast.FieldList, s *scope) {
	if field_list != nil {
		decls := ast_field_list_to_decls(field_list, decl_var, 0, s, false)
		for _, d := range decls {
			f.scope.add_named_decl(d)
		}
	}
}

func (f *auto_complete_file) cursor_in_if_head(s *ast.IfStmt) bool {
	if f.cursor > f.offset(s.If) && f.cursor <= f.offset(s.Body.Lbrace) {
		return true
	}
	return false
}

func (f *auto_complete_file) cursor_in_if_stmt(s *ast.IfStmt) bool {
	if f.cursor > f.offset(s.If) {
		// magic -10 comes from auto_complete_file.offset method, see
		// len() expr in there
		if f.offset(s.End()) == -10 || f.cursor < f.offset(s.End()) {
			return true
		}
	}
	return false
}

func (f *auto_complete_file) cursor_in_for_head(s *ast.ForStmt) bool {
	if f.cursor > f.offset(s.For) && f.cursor <= f.offset(s.Body.Lbrace) {
		return true
	}
	return false
}

func (f *auto_complete_file) cursor_in(block *ast.BlockStmt) bool {
	if f.cursor == -1 || block == nil {
		return false
	}

	if f.cursor > f.offset(block.Lbrace) && f.cursor <= f.offset(block.Rbrace) {
		return true
	}
	return false
}
