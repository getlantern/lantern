package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"time"
)

//-------------------------------------------------------------------------
// out_buffers
//
// Temporary structure for writing autocomplete response.
//-------------------------------------------------------------------------

// fields must be exported for RPC
type candidate struct {
	Name  string
	Type  string
	Class decl_class
}

type out_buffers struct {
	tmpbuf     *bytes.Buffer
	candidates []candidate
	ctx        *auto_complete_context
	tmpns      map[string]bool
	ignorecase bool
}

func new_out_buffers(ctx *auto_complete_context) *out_buffers {
	b := new(out_buffers)
	b.tmpbuf = bytes.NewBuffer(make([]byte, 0, 1024))
	b.candidates = make([]candidate, 0, 64)
	b.ctx = ctx
	return b
}

func (b *out_buffers) Len() int {
	return len(b.candidates)
}

func (b *out_buffers) Less(i, j int) bool {
	x := b.candidates[i]
	y := b.candidates[j]
	if x.Class == y.Class {
		return x.Name < y.Name
	}
	return x.Class < y.Class
}

func (b *out_buffers) Swap(i, j int) {
	b.candidates[i], b.candidates[j] = b.candidates[j], b.candidates[i]
}

func (b *out_buffers) append_decl(p, name string, decl *decl, class decl_class) {
	c1 := !g_config.ProposeBuiltins && decl.scope == g_universe_scope && decl.name != "Error"
	c2 := class != decl_invalid && decl.class != class
	c3 := class == decl_invalid && !has_prefix(name, p, b.ignorecase)
	c4 := !decl.matches()
	c5 := !check_type_expr(decl.typ)

	if c1 || c2 || c3 || c4 || c5 {
		return
	}

	decl.pretty_print_type(b.tmpbuf)
	b.candidates = append(b.candidates, candidate{
		Name:  name,
		Type:  b.tmpbuf.String(),
		Class: decl.class,
	})
	b.tmpbuf.Reset()
}

func (b *out_buffers) append_embedded(p string, decl *decl, class decl_class) {
	if decl.embedded == nil {
		return
	}

	first_level := false
	if b.tmpns == nil {
		// first level, create tmp namespace
		b.tmpns = make(map[string]bool)
		first_level = true

		// add all children of the current decl to the namespace
		for _, c := range decl.children {
			b.tmpns[c.name] = true
		}
	}

	for _, emb := range decl.embedded {
		typedecl := type_to_decl(emb, decl.scope)
		if typedecl == nil {
			continue
		}

		// prevent infinite recursion here
		if typedecl.flags&decl_visited != 0 {
			continue
		}
		typedecl.flags |= decl_visited
		defer typedecl.clear_visited()

		for _, c := range typedecl.children {
			if _, has := b.tmpns[c.name]; has {
				continue
			}
			b.append_decl(p, c.name, c, class)
			b.tmpns[c.name] = true
		}
		b.append_embedded(p, typedecl, class)
	}

	if first_level {
		// remove tmp namespace
		b.tmpns = nil
	}
}

//-------------------------------------------------------------------------
// auto_complete_context
//
// Context that holds cache structures for autocompletion needs. It
// includes cache for packages and for main package files.
//-------------------------------------------------------------------------

type auto_complete_context struct {
	current *auto_complete_file // currently edited file
	others  []*decl_file_cache  // other files of the current package
	pkg     *scope

	pcache    package_cache // packages cache
	declcache *decl_cache   // top-level declarations cache
}

func new_auto_complete_context(pcache package_cache, declcache *decl_cache) *auto_complete_context {
	c := new(auto_complete_context)
	c.current = new_auto_complete_file("", declcache.context)
	c.pcache = pcache
	c.declcache = declcache
	return c
}

func (c *auto_complete_context) update_caches() {
	// temporary map for packages that we need to check for a cache expiration
	// map is used as a set of unique items to prevent double checks
	ps := make(map[string]*package_file_cache)

	// collect import information from all of the files
	c.pcache.append_packages(ps, c.current.packages)
	c.others = get_other_package_files(c.current.name, c.current.package_name, c.declcache)
	for _, other := range c.others {
		c.pcache.append_packages(ps, other.packages)
	}

	update_packages(ps)

	// fix imports for all files
	fixup_packages(c.current.filescope, c.current.packages, c.pcache)
	for _, f := range c.others {
		fixup_packages(f.filescope, f.packages, c.pcache)
	}

	// At this point we have collected all top level declarations, now we need to
	// merge them in the common package block.
	c.merge_decls()
}

func (c *auto_complete_context) merge_decls() {
	c.pkg = new_scope(g_universe_scope)
	merge_decls(c.current.filescope, c.pkg, c.current.decls)
	merge_decls_from_packages(c.pkg, c.current.packages, c.pcache)
	for _, f := range c.others {
		merge_decls(f.filescope, c.pkg, f.decls)
		merge_decls_from_packages(c.pkg, f.packages, c.pcache)
	}
}

func (c *auto_complete_context) make_decl_set(scope *scope) map[string]*decl {
	set := make(map[string]*decl, len(c.pkg.entities)*2)
	make_decl_set_recursive(set, scope)
	return set
}

func (c *auto_complete_context) get_candidates_from_set(set map[string]*decl, partial string, class decl_class, b *out_buffers) {
	for key, value := range set {
		if value == nil {
			continue
		}
		value.infer_type()
		b.append_decl(partial, key, value, class)
	}
}

func (c *auto_complete_context) get_candidates_from_decl(cc cursor_context, class decl_class, b *out_buffers) {
	// propose all children of a subject declaration and
	for _, decl := range cc.decl.children {
		if cc.decl.class == decl_package && !ast.IsExported(decl.name) {
			continue
		}
		b.append_decl(cc.partial, decl.name, decl, class)
	}
	// propose all children of an underlying struct/interface type
	adecl := advance_to_struct_or_interface(cc.decl)
	if adecl != nil && adecl != cc.decl {
		for _, decl := range adecl.children {
			if decl.class == decl_var {
				b.append_decl(cc.partial, decl.name, decl, class)
			}
		}
	}
	// propose all children of its embedded types
	b.append_embedded(cc.partial, cc.decl, class)
}

// returns three slices of the same length containing:
// 1. apropos names
// 2. apropos types (pretty-printed)
// 3. apropos classes
// and length of the part that should be replaced (if any)
func (c *auto_complete_context) apropos(file []byte, filename string, cursor int) ([]candidate, int) {
	c.current.cursor = cursor
	c.current.name = filename

	// Update caches and parse the current file.
	// This process is quite complicated, because I was trying to design it in a
	// concurrent fashion. Apparently I'm not really good at that. Hopefully
	// will be better in future.

	// Ugly hack, but it actually may help in some cases. Insert a
	// semicolon right at the cursor location.
	filesemi := make([]byte, len(file)+1)
	copy(filesemi, file[:cursor])
	filesemi[cursor] = ';'
	copy(filesemi[cursor+1:], file[cursor:])

	// Does full processing of the currently edited file (top-level declarations plus
	// active function).
	c.current.process_data(filesemi)

	// Updates cache of other files and packages. See the function for details of
	// the process. At the end merges all the top-level declarations into the package
	// block.
	c.update_caches()

	// And we're ready to Go. ;)

	b := new_out_buffers(c)

	partial := 0
	cc, ok := c.deduce_cursor_context(file, cursor)
	if !ok {
		return nil, 0
	}

	class := decl_invalid
	switch cc.partial {
	case "const":
		class = decl_const
	case "var":
		class = decl_var
	case "type":
		class = decl_type
	case "func":
		class = decl_func
	case "package":
		class = decl_package
	}

	if cc.decl == nil {
		// In case if no declaraion is a subject of completion, propose all:
		set := c.make_decl_set(c.current.scope)
		c.get_candidates_from_set(set, cc.partial, class, b)
		if cc.partial != "" && len(b.candidates) == 0 {
			// as a fallback, try case insensitive approach
			b.ignorecase = true
			c.get_candidates_from_set(set, cc.partial, class, b)
		}
	} else {
		c.get_candidates_from_decl(cc, class, b)
		if cc.partial != "" && len(b.candidates) == 0 {
			// as a fallback, try case insensitive approach
			b.ignorecase = true
			c.get_candidates_from_decl(cc, class, b)
		}
	}
	partial = len(cc.partial)

	if len(b.candidates) == 0 {
		return nil, 0
	}

	sort.Sort(b)
	return b.candidates, partial
}

func (c *auto_complete_context) cursor_type_pkg(file []byte, filename string, cursor int) (string, string) {
	c.current.cursor = cursor
	c.current.name = filename
	c.current.process_data(file)
	c.update_caches()
	typ, pkg, ok := c.deduce_cursor_type_pkg(file, cursor)
	if !ok || typ == nil {
		return "", ""
	}

	var tmp bytes.Buffer
	pretty_print_type_expr(&tmp, typ)
	return tmp.String(), pkg
}

func update_packages(ps map[string]*package_file_cache) {
	// initiate package cache update
	done := make(chan bool)
	for _, p := range ps {
		go func(p *package_file_cache) {
			defer func() {
				if err := recover(); err != nil {
					print_backtrace(err)
					done <- false
				}
			}()
			p.update_cache()
			done <- true
		}(p)
	}

	// wait for its completion
	for _ = range ps {
		if !<-done {
			panic("One of the package cache updaters panicked")
		}
	}
}

func merge_decls(filescope *scope, pkg *scope, decls map[string]*decl) {
	for _, d := range decls {
		pkg.merge_decl(d)
	}
	filescope.parent = pkg
}

func merge_decls_from_packages(pkgscope *scope, pkgs []package_import, pcache package_cache) {
	for _, p := range pkgs {
		path, alias := p.path, p.alias
		if alias != "." {
			continue
		}
		p := pcache[path].main
		if p == nil {
			continue
		}
		for _, d := range p.children {
			if ast.IsExported(d.name) {
				pkgscope.merge_decl(d)
			}
		}
	}
}

func fixup_packages(filescope *scope, pkgs []package_import, pcache package_cache) {
	for _, p := range pkgs {
		path, alias := p.path, p.alias
		if alias == "" {
			alias = pcache[path].defalias
		}
		// skip packages that will be merged to the package scope
		if alias == "." {
			continue
		}
		filescope.replace_decl(alias, pcache[path].main)
	}
}

func get_other_package_files(filename, packageName string, declcache *decl_cache) []*decl_file_cache {
	others := find_other_package_files(filename, packageName)

	ret := make([]*decl_file_cache, len(others))
	done := make(chan *decl_file_cache)

	for _, nm := range others {
		go func(name string) {
			defer func() {
				if err := recover(); err != nil {
					print_backtrace(err)
					done <- nil
				}
			}()
			done <- declcache.get_and_update(name)
		}(nm)
	}

	for i := range others {
		ret[i] = <-done
		if ret[i] == nil {
			panic("One of the decl cache updaters panicked")
		}
	}

	return ret
}

func find_other_package_files(filename, package_name string) []string {
	if filename == "" {
		return nil
	}

	dir, file := filepath.Split(filename)
	files_in_dir, err := readdir(dir)
	if err != nil {
		panic(err)
	}

	count := 0
	for _, stat := range files_in_dir {
		ok, _ := filepath.Match("*.go", stat.Name())
		if !ok || stat.Name() == file {
			continue
		}
		count++
	}

	out := make([]string, 0, count)
	for _, stat := range files_in_dir {
		const non_regular = os.ModeDir | os.ModeSymlink |
			os.ModeDevice | os.ModeNamedPipe | os.ModeSocket

		ok, _ := filepath.Match("*.go", stat.Name())
		if !ok || stat.Name() == file || stat.Mode()&non_regular != 0 {
			continue
		}

		abspath := filepath.Join(dir, stat.Name())
		if file_package_name(abspath) == package_name {
			n := len(out)
			out = out[:n+1]
			out[n] = abspath
		}
	}

	return out
}

func file_package_name(filename string) string {
	file, _ := parser.ParseFile(token.NewFileSet(), filename, nil, parser.PackageClauseOnly)
	return file.Name.Name
}

func make_decl_set_recursive(set map[string]*decl, scope *scope) {
	for name, ent := range scope.entities {
		if _, ok := set[name]; !ok {
			set[name] = ent
		}
	}
	if scope.parent != nil {
		make_decl_set_recursive(set, scope.parent)
	}
}

func check_func_field_list(f *ast.FieldList) bool {
	if f == nil {
		return true
	}

	for _, field := range f.List {
		if !check_type_expr(field.Type) {
			return false
		}
	}
	return true
}

// checks for a type expression correctness, it the type expression has
// ast.BadExpr somewhere, returns false, otherwise true
func check_type_expr(e ast.Expr) bool {
	switch t := e.(type) {
	case *ast.StarExpr:
		return check_type_expr(t.X)
	case *ast.ArrayType:
		return check_type_expr(t.Elt)
	case *ast.SelectorExpr:
		return check_type_expr(t.X)
	case *ast.FuncType:
		a := check_func_field_list(t.Params)
		b := check_func_field_list(t.Results)
		return a && b
	case *ast.MapType:
		a := check_type_expr(t.Key)
		b := check_type_expr(t.Value)
		return a && b
	case *ast.Ellipsis:
		return check_type_expr(t.Elt)
	case *ast.ChanType:
		return check_type_expr(t.Value)
	case *ast.BadExpr:
		return false
	default:
		return true
	}
	return true
}

//-------------------------------------------------------------------------
// Status output
//-------------------------------------------------------------------------

type decl_slice []*decl

func (s decl_slice) Less(i, j int) bool {
	if s[i].class != s[j].class {
		return s[i].name < s[j].name
	}
	return s[i].class < s[j].class
}
func (s decl_slice) Len() int      { return len(s) }
func (s decl_slice) Swap(i, j int) { s[i], s[j] = s[j], s[i] }

const (
	color_red          = "\033[0;31m"
	color_red_bold     = "\033[1;31m"
	color_green        = "\033[0;32m"
	color_green_bold   = "\033[1;32m"
	color_yellow       = "\033[0;33m"
	color_yellow_bold  = "\033[1;33m"
	color_blue         = "\033[0;34m"
	color_blue_bold    = "\033[1;34m"
	color_magenta      = "\033[0;35m"
	color_magenta_bold = "\033[1;35m"
	color_cyan         = "\033[0;36m"
	color_cyan_bold    = "\033[1;36m"
	color_white        = "\033[0;37m"
	color_white_bold   = "\033[1;37m"
	color_none         = "\033[0m"
)

var g_decl_class_to_color = [...]string{
	decl_const:        color_white_bold,
	decl_var:          color_magenta,
	decl_type:         color_cyan,
	decl_func:         color_green,
	decl_package:      color_red,
	decl_methods_stub: color_red,
}

var g_decl_class_to_string_status = [...]string{
	decl_const:        "  const",
	decl_var:          "    var",
	decl_type:         "   type",
	decl_func:         "   func",
	decl_package:      "package",
	decl_methods_stub: "   stub",
}

func (c *auto_complete_context) status() string {

	buf := bytes.NewBuffer(make([]byte, 0, 4096))
	fmt.Fprintf(buf, "Server's GOMAXPROCS == %d\n", runtime.GOMAXPROCS(0))
	fmt.Fprintf(buf, "\nPackage cache contains %d entries\n", len(c.pcache))
	fmt.Fprintf(buf, "\nListing these entries:\n")
	for _, mod := range c.pcache {
		fmt.Fprintf(buf, "\tname: %s (default alias: %s)\n", mod.name, mod.defalias)
		fmt.Fprintf(buf, "\timports %d declarations and %d packages\n", len(mod.main.children), len(mod.others))
		if mod.mtime == -1 {
			fmt.Fprintf(buf, "\tthis package stays in cache forever (built-in package)\n")
		} else {
			mtime := time.Unix(0, mod.mtime)
			fmt.Fprintf(buf, "\tlast modification time: %s\n", mtime)
		}
		fmt.Fprintf(buf, "\n")
	}
	if c.current.name != "" {
		fmt.Fprintf(buf, "Last edited file: %s (package: %s)\n", c.current.name, c.current.package_name)
		if len(c.others) > 0 {
			fmt.Fprintf(buf, "\nOther files from the current package:\n")
		}
		for _, f := range c.others {
			fmt.Fprintf(buf, "\t%s\n", f.name)
		}
		fmt.Fprintf(buf, "\nListing declarations from files:\n")

		const status_decls = "\t%s%s" + color_none + " " + color_yellow + "%s" + color_none + "\n"
		const status_decls_children = "\t%s%s" + color_none + " " + color_yellow + "%s" + color_none + " (%d)\n"

		fmt.Fprintf(buf, "\n%s:\n", c.current.name)
		ds := make(decl_slice, len(c.current.decls))
		i := 0
		for _, d := range c.current.decls {
			ds[i] = d
			i++
		}
		sort.Sort(ds)
		for _, d := range ds {
			if len(d.children) > 0 {
				fmt.Fprintf(buf, status_decls_children,
					g_decl_class_to_color[d.class],
					g_decl_class_to_string_status[d.class],
					d.name, len(d.children))
			} else {
				fmt.Fprintf(buf, status_decls,
					g_decl_class_to_color[d.class],
					g_decl_class_to_string_status[d.class],
					d.name)
			}
		}

		for _, f := range c.others {
			fmt.Fprintf(buf, "\n%s:\n", f.name)
			ds = make(decl_slice, len(f.decls))
			i = 0
			for _, d := range f.decls {
				ds[i] = d
				i++
			}
			sort.Sort(ds)
			for _, d := range ds {
				if len(d.children) > 0 {
					fmt.Fprintf(buf, status_decls_children,
						g_decl_class_to_color[d.class],
						g_decl_class_to_string_status[d.class],
						d.name, len(d.children))
				} else {
					fmt.Fprintf(buf, status_decls,
						g_decl_class_to_color[d.class],
						g_decl_class_to_string_status[d.class],
						d.name)
				}
			}
		}
	}
	return buf.String()
}
