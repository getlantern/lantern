package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

// tagParser contains the data needed while parsing.
type tagParser struct {
	fset     *token.FileSet
	tags     []Tag    // list of created tags
	types    []string // all types we encounter, used to determine the constructors
	relative bool     // should filenames be relative to basepath
	basepath string   // output file directory
}

// Parse parses the source in filename and returns a list of tags. If relative
// is true, the filenames in the list of tags are relative to basepath.
func Parse(filename string, relative bool, basepath string) ([]Tag, error) {
	p := &tagParser{
		fset:     token.NewFileSet(),
		tags:     []Tag{},
		types:    make([]string, 0),
		relative: relative,
		basepath: basepath,
	}

	f, err := parser.ParseFile(p.fset, filename, nil, 0)
	if err != nil {
		return nil, err
	}

	// package
	p.parsePackage(f)

	// imports
	p.parseImports(f)

	// declarations
	p.parseDeclarations(f)

	return p.tags, nil
}

// parsePackage creates a package tag.
func (p *tagParser) parsePackage(f *ast.File) {
	p.tags = append(p.tags, p.createTag(f.Name.Name, f.Name.Pos(), Package))
}

// parseImports creates an import tag for each import.
func (p *tagParser) parseImports(f *ast.File) {
	for _, im := range f.Imports {
		name := strings.Trim(im.Path.Value, "\"")
		p.tags = append(p.tags, p.createTag(name, im.Path.Pos(), Import))
	}
}

// parseDeclarations creates a tag for each function, type or value declaration.
func (p *tagParser) parseDeclarations(f *ast.File) {
	// first parse the type and value declarations, so that we have a list of all
	// known types before parsing the functions.
	for _, d := range f.Decls {
		if decl, ok := d.(*ast.GenDecl); ok {
			for _, s := range decl.Specs {
				switch ts := s.(type) {
				case *ast.TypeSpec:
					p.parseTypeDeclaration(ts)
				case *ast.ValueSpec:
					p.parseValueDeclaration(ts)
				}
			}
		}
	}

	// now parse all the functions
	for _, d := range f.Decls {
		if decl, ok := d.(*ast.FuncDecl); ok {
			p.parseFunction(decl)
		}
	}
}

// parseFunction creates a tag for function declaration f.
func (p *tagParser) parseFunction(f *ast.FuncDecl) {
	tag := p.createTag(f.Name.Name, f.Pos(), Function)

	tag.Fields[Access] = getAccess(tag.Name)
	tag.Fields[Signature] = fmt.Sprintf("(%s)", getTypes(f.Type.Params, true))
	tag.Fields[TypeField] = getTypes(f.Type.Results, false)

	if f.Recv != nil && len(f.Recv.List) > 0 {
		// this function has a receiver, set the type to Method
		tag.Fields[ReceiverType] = getType(f.Recv.List[0].Type, false)
		tag.Type = Method
	} else if name, ok := p.belongsToReceiver(f.Type.Results); ok {
		// this function does not have a receiver, but it belongs to one based
		// on its return values; its type will be Function instead of Method.
		tag.Fields[ReceiverType] = name
		tag.Type = Function
	}

	p.tags = append(p.tags, tag)
}

// parseTypeDeclaration creates a tag for type declaration ts and for each
// field in case of a struct, or each method in case of an interface.
func (p *tagParser) parseTypeDeclaration(ts *ast.TypeSpec) {
	tag := p.createTag(ts.Name.Name, ts.Pos(), Type)

	tag.Fields[Access] = getAccess(tag.Name)

	switch s := ts.Type.(type) {
	case *ast.StructType:
		tag.Fields[TypeField] = "struct"
		p.parseStructFields(tag.Name, s)
		p.types = append(p.types, tag.Name)
	case *ast.InterfaceType:
		tag.Fields[TypeField] = "interface"
		tag.Type = Interface
		p.parseInterfaceMethods(tag.Name, s)
	default:
		tag.Fields[TypeField] = getType(ts.Type, true)
	}

	p.tags = append(p.tags, tag)
}

// parseValueDeclaration creates a tag for each variable or constant declaration,
// unless the declaration uses a blank identifier.
func (p *tagParser) parseValueDeclaration(v *ast.ValueSpec) {
	for _, d := range v.Names {
		if d.Name == "_" {
			continue
		}

		tag := p.createTag(d.Name, d.Pos(), Variable)
		tag.Fields[Access] = getAccess(tag.Name)

		if v.Type != nil {
			tag.Fields[TypeField] = getType(v.Type, true)
		}

		switch d.Obj.Kind {
		case ast.Var:
			tag.Type = Variable
		case ast.Con:
			tag.Type = Constant
		}
		p.tags = append(p.tags, tag)
	}
}

// parseStructFields creates a tag for each field in struct s, using name as the
// tags ctype.
func (p *tagParser) parseStructFields(name string, s *ast.StructType) {
	for _, f := range s.Fields.List {
		var tag Tag
		if len(f.Names) > 0 {
			for _, n := range f.Names {
				tag = p.createTag(n.Name, n.Pos(), Field)
				tag.Fields[Access] = getAccess(tag.Name)
				tag.Fields[ReceiverType] = name
				tag.Fields[TypeField] = getType(f.Type, true)
				p.tags = append(p.tags, tag)
			}
		} else {
			// embedded field
			tag = p.createTag(getType(f.Type, true), f.Pos(), Embedded)
			tag.Fields[Access] = getAccess(tag.Name)
			tag.Fields[ReceiverType] = name
			tag.Fields[TypeField] = getType(f.Type, true)
			p.tags = append(p.tags, tag)
		}
	}
}

// parseInterfaceMethods creates a tag for each method in interface s, using name
// as the tags ctype.
func (p *tagParser) parseInterfaceMethods(name string, s *ast.InterfaceType) {
	for _, f := range s.Methods.List {
		var tag Tag
		if len(f.Names) > 0 {
			tag = p.createTag(f.Names[0].Name, f.Names[0].Pos(), Method)
		} else {
			// embedded interface
			tag = p.createTag(getType(f.Type, true), f.Pos(), Embedded)
		}

		tag.Fields[Access] = getAccess(tag.Name)

		if t, ok := f.Type.(*ast.FuncType); ok {
			tag.Fields[Signature] = fmt.Sprintf("(%s)", getTypes(t.Params, true))
			tag.Fields[TypeField] = getTypes(t.Results, false)
		}

		tag.Fields[InterfaceType] = name

		p.tags = append(p.tags, tag)
	}
}

// createTag creates a new tag, using pos to find the filename and set the line number.
func (p *tagParser) createTag(name string, pos token.Pos, tagType TagType) Tag {
	f := p.fset.File(pos).Name()
	if p.relative {
		if abs, err := filepath.Abs(f); err != nil {
			fmt.Fprintf(os.Stderr, "could not determine absolute path: %s\n", err)
		} else if rel, err := filepath.Rel(p.basepath, abs); err != nil {
			fmt.Fprintf(os.Stderr, "could not determine relative path: %s\n", err)
		} else {
			f = rel
		}
	}
	return NewTag(name, f, p.fset.Position(pos).Line, tagType)
}

// belongsToReceiver checks if a function with these return types belongs to
// a receiver. If it belongs to a receiver, the name of that receiver will be
// returned with ok set to true. Otherwise ok will be false.
// Behavior should be similar to how go doc decides when a function belongs to
// a receiver (gosrc/pkg/go/doc/reader.go).
func (p *tagParser) belongsToReceiver(types *ast.FieldList) (name string, ok bool) {
	if types == nil || types.NumFields() == 0 {
		return "", false
	}

	// If the first return type has more than 1 result associated with
	// it, it should not belong to that receiver.
	// Similar behavior as go doc (go source/.
	if len(types.List[0].Names) > 1 {
		return "", false
	}

	// get name of the first return type
	t := getType(types.List[0].Type, false)

	// check if it exists in the current list of known types
	for _, knownType := range p.types {
		if t == knownType {
			return knownType, true
		}
	}

	return "", false
}

// getTypes returns a comma separated list of types in fields. If includeNames is
// true each type is preceded by a comma separated list of parameter names.
func getTypes(fields *ast.FieldList, includeNames bool) string {
	if fields == nil {
		return ""
	}

	types := make([]string, len(fields.List))
	for i, param := range fields.List {
		if len(param.Names) > 0 {
			// there are named parameters, there may be multiple names for a single type
			t := getType(param.Type, true)

			if includeNames {
				// join all the names, followed by their type
				names := make([]string, len(param.Names))
				for j, n := range param.Names {
					names[j] = n.Name
				}
				t = fmt.Sprintf("%s %s", strings.Join(names, ", "), t)
			} else {
				if len(param.Names) > 1 {
					// repeat t len(param.Names) times
					t = strings.Repeat(fmt.Sprintf("%s, ", t), len(param.Names))

					// remove trailing comma and space
					t = t[:len(t)-2]
				}
			}

			types[i] = t
		} else {
			// no named parameters
			types[i] = getType(param.Type, true)
		}
	}

	return strings.Join(types, ", ")
}

// getType returns a string representation of the type of node. If star is true and the
// type is a pointer, a * will be prepended to the string.
func getType(node ast.Node, star bool) (paramType string) {
	switch t := node.(type) {
	case *ast.Ident:
		paramType = t.Name
	case *ast.StarExpr:
		if star {
			paramType = "*" + getType(t.X, star)
		} else {
			paramType = getType(t.X, star)
		}
	case *ast.SelectorExpr:
		paramType = getType(t.X, star) + "." + getType(t.Sel, star)
	case *ast.ArrayType:
		if l, ok := t.Len.(*ast.BasicLit); ok {
			paramType = fmt.Sprintf("[%s]%s", l.Value, getType(t.Elt, star))
		} else {
			paramType = "[]" + getType(t.Elt, star)
		}
	case *ast.FuncType:
		fparams := getTypes(t.Params, true)
		fresult := getTypes(t.Results, false)

		if len(fresult) > 0 {
			paramType = fmt.Sprintf("func(%s) %s", fparams, fresult)
		} else {
			paramType = fmt.Sprintf("func(%s)", fparams)
		}
	case *ast.MapType:
		paramType = fmt.Sprintf("map[%s]%s", getType(t.Key, true), getType(t.Value, true))
	case *ast.ChanType:
		paramType = fmt.Sprintf("chan %s", getType(t.Value, true))
	case *ast.InterfaceType:
		paramType = "interface{}"
	}
	return
}

// getAccess returns the string "public" if name is considered an exported name, otherwise
// the string "private" is returned.
func getAccess(name string) (access string) {
	if idx := strings.LastIndex(name, "."); idx > -1 && idx < len(name) {
		name = name[idx+1:]
	}

	if ast.IsExported(name) {
		access = "public"
	} else {
		access = "private"
	}
	return
}
