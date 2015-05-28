package main

import "debug/elf"
import "text/scanner"
import "bytes"
import "errors"
import "io"
import "fmt"
import "strconv"
import "go/ast"
import "go/token"
import "strings"

var builtin_type_names = []*ast.Ident{
	nil,
	ast.NewIdent("int8"),
	ast.NewIdent("int16"),
	ast.NewIdent("int32"),
	ast.NewIdent("int64"),
	ast.NewIdent("uint8"),
	ast.NewIdent("uint16"),
	ast.NewIdent("uint32"),
	ast.NewIdent("uint64"),
	ast.NewIdent("float32"),
	ast.NewIdent("float64"),
	ast.NewIdent("int"),
	ast.NewIdent("uint"),
	ast.NewIdent("uintptr"),
	nil,
	ast.NewIdent("bool"),
	ast.NewIdent("string"),
	ast.NewIdent("complex64"),
	ast.NewIdent("complex128"),
	ast.NewIdent("error"),
	ast.NewIdent("byte"),
	ast.NewIdent("rune"),
}

const (
	smallest_builtin_code = -21
)

func read_import_data(import_path string) ([]byte, error) {
	// TODO: find file location
	filename := import_path + ".gox"

	f, err := elf.Open(filename)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	sec := f.Section(".go_export")
	if sec == nil {
		return nil, errors.New("missing .go_export section in the file: " + filename)
	}

	return sec.Data()
}

func parse_import_data(data []byte) {
	buf := bytes.NewBuffer(data)
	var p import_data_parser
	p.init(buf)

	// magic
	p.expect_ident("v1")
	p.expect(';')

	// package ident
	p.expect_ident("package")
	pkgid := p.expect(scanner.Ident)
	p.expect(';')

	println("package ident: " + pkgid)

	// package path
	p.expect_ident("pkgpath")
	pkgpath := p.expect(scanner.Ident)
	p.expect(';')

	println("package path: " + pkgpath)

	// package priority
	p.expect_ident("priority")
	priority := p.expect(scanner.Int)
	p.expect(';')

	println("package priority: " + priority)

	// import init functions
	for p.toktype == scanner.Ident && p.token() == "import" {
		p.expect_ident("import")
		pkgname := p.expect(scanner.Ident)
		pkgpath := p.expect(scanner.Ident)
		importpath := p.expect(scanner.String)
		p.expect(';')
		println("import " + pkgname + " " + pkgpath + " " + importpath)
	}

	if p.toktype == scanner.Ident && p.token() == "init" {
		p.expect_ident("init")
		for p.toktype != ';' {
			pkgname := p.expect(scanner.Ident)
			initname := p.expect(scanner.Ident)
			prio := p.expect(scanner.Int)
			println("init " + pkgname + " " + initname + " " + fmt.Sprint(prio))
		}
		p.expect(';')
	}

loop:
	for {
		switch tok := p.expect(scanner.Ident); tok {
		case "const":
			p.read_const()
		case "type":
			p.read_type_decl()
		case "var":
			p.read_var()
		case "func":
			p.read_func()
		case "checksum":
			p.read_checksum()
			break loop
		default:
			panic(errors.New("unexpected identifier token: '" + tok + "'"))
		}
	}
}

//----------------------------------------------------------------------------
// import data parser
//----------------------------------------------------------------------------

type import_data_type struct {
	name  string
	type_ ast.Expr
}

type import_data_parser struct {
	scanner   scanner.Scanner
	toktype   rune
	typetable []*import_data_type
}

func (this *import_data_parser) init(reader io.Reader) {
	this.scanner.Mode = scanner.ScanIdents | scanner.ScanInts | scanner.ScanStrings | scanner.ScanFloats
	this.scanner.Init(reader)
	this.next()

	// len == 1 here, because 0 is an invalid type index
	this.typetable = make([]*import_data_type, 1, 50)
}

func (this *import_data_parser) next() {
	this.toktype = this.scanner.Scan()
}

func (this *import_data_parser) token() string {
	return this.scanner.TokenText()
}

// internal, use expect(scanner.Ident) instead
func (this *import_data_parser) read_ident() string {
	id := ""
	prev := rune(0)

loop:
	for {
		switch this.toktype {
		case scanner.Ident:
			if prev == scanner.Ident {
				break loop
			}

			prev = this.toktype
			id += this.token()
			this.next()
		case '.', '?', '$':
			prev = this.toktype
			id += string(this.toktype)
			this.next()
		default:
			break loop
		}
	}

	if id == "" {
		this.errorf("identifier expected, got %s", scanner.TokenString(this.toktype))
	}
	return id
}

func (this *import_data_parser) read_int() string {
	val := ""
	if this.toktype == '-' {
		this.next()
		val += "-"
	}
	if this.toktype != scanner.Int {
		this.errorf("expected: %s, got: %s", scanner.TokenString(scanner.Int), scanner.TokenString(this.toktype))
	}

	val += this.token()
	this.next()
	return val
}

func (this *import_data_parser) errorf(format string, args ...interface{}) {
	panic(errors.New(fmt.Sprintf(format, args...)))
}

// makes sure that the current token is 'x', returns it and reads the next one
func (this *import_data_parser) expect(x rune) string {
	if x == scanner.Ident {
		// special case, in gccgo import data identifier is not exactly a scanner.Ident
		return this.read_ident()
	}

	if x == scanner.Int {
		// another special case, handle negative ints as well
		return this.read_int()
	}

	if this.toktype != x {
		this.errorf("expected: %s, got: %s", scanner.TokenString(x), scanner.TokenString(this.toktype))
	}

	tok := this.token()
	this.next()
	return tok
}

// makes sure that the following set of tokens matches 'special', reads the next one
func (this *import_data_parser) expect_special(special string) {
	i := 0
	for i < len(special) {
		if this.toktype != rune(special[i]) {
			break
		}

		this.next()
		i++
	}

	if i < len(special) {
		this.errorf("expected: \"%s\", got something else", special)
	}
}

// makes sure that the current token is scanner.Ident and is equals to 'ident', reads the next one
func (this *import_data_parser) expect_ident(ident string) {
	tok := this.expect(scanner.Ident)
	if tok != ident {
		this.errorf("expected identifier: \"%s\", got: \"%s\"", ident, tok)
	}
}

func (this *import_data_parser) read_type() ast.Expr {
	type_, name := this.read_type_full()
	if name != "" {
		return ast.NewIdent(name)
	}
	return type_
}

func (this *import_data_parser) read_type_full() (ast.Expr, string) {
	this.expect('<')
	this.expect_ident("type")

	numstr := this.expect(scanner.Int)
	num, err := strconv.ParseInt(numstr, 10, 32)
	if err != nil {
		panic(err)
	}

	if this.toktype == '>' {
		// was already declared previously
		this.next()
		if num < 0 {
			if num < smallest_builtin_code {
				this.errorf("out of range built-in type code")
			}
			return builtin_type_names[-num], ""
		} else {
			// lookup type table
			type_ := this.typetable[num]
			return type_.type_, type_.name
		}
	}

	this.typetable = append(this.typetable, &import_data_type{})
	var type_ = this.typetable[len(this.typetable)-1]

	switch this.toktype {
	case scanner.String:
		// named type
		s := this.expect(scanner.String)
		type_.name = s[1 : len(s)-1] // remove ""
		fallthrough
	default:
		// unnamed type
		switch this.toktype {
		case scanner.Ident:
			switch tok := this.token(); tok {
			case "struct":
				type_.type_ = this.read_struct_type()
			case "interface":
				type_.type_ = this.read_interface_type()
			case "map":
				type_.type_ = this.read_map_type()
			case "chan":
				type_.type_ = this.read_chan_type()
			default:
				this.errorf("unknown type class token: \"%s\"", tok)
			}
		case '[':
			type_.type_ = this.read_array_or_slice_type()
		case '*':
			this.next()
			if this.token() == "any" {
				this.next()
				type_.type_ = &ast.StarExpr{X: ast.NewIdent("any")}
			} else {
				type_.type_ = &ast.StarExpr{X: this.read_type()}
			}
		case '(':
			type_.type_ = this.read_func_type()
		case '<':
			type_.type_ = this.read_type()
		}
	}

	for this.toktype != '>' {
		// must be a method or many methods
		this.expect_ident("func")
		this.read_method()
	}

	this.expect('>')
	return type_.type_, type_.name
}

func (this *import_data_parser) read_map_type() ast.Expr {
	this.expect_ident("map")
	this.expect('[')
	key := this.read_type()
	this.expect(']')
	val := this.read_type()
	return &ast.MapType{Key: key, Value: val}
}

func (this *import_data_parser) read_chan_type() ast.Expr {
	dir := ast.SEND | ast.RECV
	this.expect_ident("chan")
	switch this.toktype {
	case '-':
		// chan -< <type>
		this.expect_special("-<")
		dir = ast.SEND
	case '<':
		// slight ambiguity here
		if this.scanner.Peek() == '-' {
			// chan <- <type>
			this.expect_special("<-")
			dir = ast.RECV
		}
		// chan <type>
	default:
		this.errorf("unexpected token: \"%s\"", this.token())
	}

	return &ast.ChanType{Dir: dir, Value: this.read_type()}
}

func (this *import_data_parser) read_field() *ast.Field {
	var tag string
	name := this.expect(scanner.Ident)
	type_ := this.read_type()
	if this.toktype == scanner.String {
		tag = this.expect(scanner.String)
	}

	return &ast.Field{
		Names: []*ast.Ident{ast.NewIdent(name)},
		Type:  type_,
		Tag:   &ast.BasicLit{Kind: token.STRING, Value: tag},
	}
}

func (this *import_data_parser) read_struct_type() ast.Expr {
	var fields []*ast.Field
	read_field := func() {
		field := this.read_field()
		fields = append(fields, field)
	}

	this.expect_ident("struct")
	this.expect('{')
	for this.toktype != '}' {
		read_field()
		this.expect(';')
	}
	this.expect('}')
	return &ast.StructType{Fields: &ast.FieldList{List: fields}}
}

func (this *import_data_parser) read_parameter() *ast.Field {
	name := this.expect(scanner.Ident)

	var type_ ast.Expr
	if this.toktype == '.' {
		this.expect_special("...")
		type_ = &ast.Ellipsis{Elt: this.read_type()}
	} else {
		type_ = this.read_type()
	}

	var tag string
	if this.toktype == scanner.String {
		tag = this.expect(scanner.String)
	}

	return &ast.Field{
		Names: []*ast.Ident{ast.NewIdent(name)},
		Type:  type_,
		Tag:   &ast.BasicLit{Kind: token.STRING, Value: tag},
	}
}

func (this *import_data_parser) read_parameters() *ast.FieldList {
	var fields []*ast.Field
	read_parameter := func() {
		parameter := this.read_parameter()
		fields = append(fields, parameter)
	}

	this.expect('(')
	if this.toktype != ')' {
		read_parameter()
		for this.toktype == ',' {
			this.next() // skip ','
			read_parameter()
		}
	}
	this.expect(')')

	if fields == nil {
		return nil
	}
	return &ast.FieldList{List: fields}
}

func (this *import_data_parser) read_func_type() *ast.FuncType {
	var params, results *ast.FieldList

	params = this.read_parameters()
	switch this.toktype {
	case '<':
		field := &ast.Field{Type: this.read_type()}
		results = &ast.FieldList{List: []*ast.Field{field}}
	case '(':
		results = this.read_parameters()
	}

	return &ast.FuncType{Params: params, Results: results}
}

func (this *import_data_parser) read_method_or_embed_spec() *ast.Field {
	var type_ ast.Expr
	name := this.expect(scanner.Ident)
	if name == "?" {
		// TODO: ast.SelectorExpr conversion here possibly
		type_ = this.read_type()
	} else {
		type_ = this.read_func_type()
	}
	return &ast.Field{
		Names: []*ast.Ident{ast.NewIdent(name)},
		Type:  type_,
	}
}

func (this *import_data_parser) read_interface_type() ast.Expr {
	var methods []*ast.Field
	read_method := func() {
		method := this.read_method_or_embed_spec()
		methods = append(methods, method)
	}

	this.expect_ident("interface")
	this.expect('{')
	for this.toktype != '}' {
		read_method()
		this.expect(';')
	}
	this.expect('}')
	return &ast.InterfaceType{Methods: &ast.FieldList{List: methods}}
}

func (this *import_data_parser) read_method() {
	var buf1, buf2 bytes.Buffer
	recv := this.read_parameters()
	name := this.expect(scanner.Ident)
	type_ := this.read_func_type()
	this.expect(';')
	pretty_print_type_expr(&buf1, recv.List[0].Type)
	pretty_print_type_expr(&buf2, type_)
	println("func (" + buf1.String() + ") " + name + buf2.String()[4:])
}

func (this *import_data_parser) read_array_or_slice_type() ast.Expr {
	var length ast.Expr

	this.expect('[')
	if this.toktype == scanner.Int {
		// array type
		length = &ast.BasicLit{Kind: token.INT, Value: this.expect(scanner.Int)}
	}
	this.expect(']')
	return &ast.ArrayType{
		Len: length,
		Elt: this.read_type(),
	}
}

func (this *import_data_parser) read_const() {
	var buf bytes.Buffer

	// const keyword was already consumed
	c := "const " + this.expect(scanner.Ident)
	if this.toktype != '=' {
		// parse type
		type_ := this.read_type()
		pretty_print_type_expr(&buf, type_)
		c += " " + buf.String()
	}

	this.expect('=')

	// parse expr
	this.next()
	this.expect(';')
	println(c)
}

func (this *import_data_parser) read_checksum() {
	// checksum keyword was already consumed
	for this.toktype != ';' {
		this.next()
	}
	this.expect(';')
}

func (this *import_data_parser) read_type_decl() {
	var buf bytes.Buffer
	// type keyword was already consumed
	type_, name := this.read_type_full()
	this.expect(';')
	pretty_print_type_expr(&buf, type_)
	println("type " + name + " " + buf.String())
}

func (this *import_data_parser) read_var() {
	var buf bytes.Buffer
	// var keyword was already consumed
	name := this.expect(scanner.Ident)
	type_ := this.read_type()
	this.expect(';')
	pretty_print_type_expr(&buf, type_)
	println("var " + name + " " + buf.String())
}

func (this *import_data_parser) read_func() {
	var buf bytes.Buffer
	// func keyword was already consumed
	name := this.expect(scanner.Ident)
	type_ := this.read_func_type()
	this.expect(';')
	pretty_print_type_expr(&buf, type_)
	println("func " + name + buf.String()[4:])
}

//-------------------------------------------------------------------------
// Pretty printing
//-------------------------------------------------------------------------

func get_array_len(e ast.Expr) string {
	switch t := e.(type) {
	case *ast.BasicLit:
		return string(t.Value)
	case *ast.Ellipsis:
		return "..."
	}
	return ""
}

func pretty_print_type_expr(out io.Writer, e ast.Expr) {
	switch t := e.(type) {
	case *ast.StarExpr:
		fmt.Fprintf(out, "*")
		pretty_print_type_expr(out, t.X)
	case *ast.Ident:
		if strings.HasPrefix(t.Name, "$") {
			// beautify anonymous types
			switch t.Name[1] {
			case 's':
				fmt.Fprintf(out, "struct")
			case 'i':
				fmt.Fprintf(out, "interface")
			}
		} else {
			fmt.Fprintf(out, t.Name)
		}
	case *ast.ArrayType:
		al := ""
		if t.Len != nil {
			println(t.Len)
			al = get_array_len(t.Len)
		}
		if al != "" {
			fmt.Fprintf(out, "[%s]", al)
		} else {
			fmt.Fprintf(out, "[]")
		}
		pretty_print_type_expr(out, t.Elt)
	case *ast.SelectorExpr:
		pretty_print_type_expr(out, t.X)
		fmt.Fprintf(out, ".%s", t.Sel.Name)
	case *ast.FuncType:
		fmt.Fprintf(out, "func(")
		pretty_print_func_field_list(out, t.Params)
		fmt.Fprintf(out, ")")

		buf := bytes.NewBuffer(make([]byte, 0, 256))
		nresults := pretty_print_func_field_list(buf, t.Results)
		if nresults > 0 {
			results := buf.String()
			if strings.Index(results, ",") != -1 {
				results = "(" + results + ")"
			}
			fmt.Fprintf(out, " %s", results)
		}
	case *ast.MapType:
		fmt.Fprintf(out, "map[")
		pretty_print_type_expr(out, t.Key)
		fmt.Fprintf(out, "]")
		pretty_print_type_expr(out, t.Value)
	case *ast.InterfaceType:
		fmt.Fprintf(out, "interface{}")
	case *ast.Ellipsis:
		fmt.Fprintf(out, "...")
		pretty_print_type_expr(out, t.Elt)
	case *ast.StructType:
		fmt.Fprintf(out, "struct")
	case *ast.ChanType:
		switch t.Dir {
		case ast.RECV:
			fmt.Fprintf(out, "<-chan ")
		case ast.SEND:
			fmt.Fprintf(out, "chan<- ")
		case ast.SEND | ast.RECV:
			fmt.Fprintf(out, "chan ")
		}
		pretty_print_type_expr(out, t.Value)
	case *ast.ParenExpr:
		fmt.Fprintf(out, "(")
		pretty_print_type_expr(out, t.X)
		fmt.Fprintf(out, ")")
	case *ast.BadExpr:
		// TODO: probably I should check that in a separate function
		// and simply discard declarations with BadExpr as a part of their
		// type
	default:
		// should never happen
		panic("unknown type")
	}
}

func pretty_print_func_field_list(out io.Writer, f *ast.FieldList) int {
	count := 0
	if f == nil {
		return count
	}
	for i, field := range f.List {
		// names
		if field.Names != nil {
			hasNonblank := false
			for j, name := range field.Names {
				if name.Name != "?" {
					hasNonblank = true
					fmt.Fprintf(out, "%s", name.Name)
					if j != len(field.Names)-1 {
						fmt.Fprintf(out, ", ")
					}
				}
				count++
			}
			if hasNonblank {
				fmt.Fprintf(out, " ")
			}
		} else {
			count++
		}

		// type
		pretty_print_type_expr(out, field.Type)

		// ,
		if i != len(f.List)-1 {
			fmt.Fprintf(out, ", ")
		}
	}
	return count
}

func main() {
	data, err := read_import_data("io")
	if err != nil {
		panic(err)
	}
	parse_import_data(data)
}
