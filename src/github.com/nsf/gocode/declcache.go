package main

import (
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
)

//-------------------------------------------------------------------------
// []package_import
//-------------------------------------------------------------------------

type package_import struct {
	alias string
	path  string
}

// Parses import declarations until the first non-import declaration and fills
// `packages` array with import information.
func collect_package_imports(filename string, decls []ast.Decl, context build.Context) []package_import {
	pi := make([]package_import, 0, 16)
	for _, decl := range decls {
		if gd, ok := decl.(*ast.GenDecl); ok && gd.Tok == token.IMPORT {
			for _, spec := range gd.Specs {
				imp := spec.(*ast.ImportSpec)
				path, alias := path_and_alias(imp)
				path, ok := abs_path_for_package(filename, path, context)
				if ok && alias != "_" {
					pi = append(pi, package_import{alias, path})
				}
			}
		} else {
			break
		}
	}
	return pi
}

//-------------------------------------------------------------------------
// decl_file_cache
//
// Contains cache for top-level declarations of a file as well as its
// contents, AST and import information.
//-------------------------------------------------------------------------

type decl_file_cache struct {
	name  string // file name
	mtime int64  // last modification time

	decls     map[string]*decl // top-level declarations
	error     error            // last error
	packages  []package_import // import information
	filescope *scope

	fset    *token.FileSet
	context build.Context
}

func new_decl_file_cache(name string, context build.Context) *decl_file_cache {
	return &decl_file_cache{
		name:    name,
		context: context,
	}
}

func (f *decl_file_cache) update() {
	stat, err := os.Stat(f.name)
	if err != nil {
		f.decls = nil
		f.error = err
		f.fset = nil
		return
	}

	statmtime := stat.ModTime().UnixNano()
	if f.mtime == statmtime {
		return
	}

	f.mtime = statmtime
	f.read_file()
}

func (f *decl_file_cache) read_file() {
	var data []byte
	data, f.error = file_reader.read_file(f.name)
	if f.error != nil {
		return
	}
	data, _ = filter_out_shebang(data)

	f.process_data(data)
}

func (f *decl_file_cache) process_data(data []byte) {
	var file *ast.File
	f.fset = token.NewFileSet()
	file, f.error = parser.ParseFile(f.fset, "", data, 0)
	f.filescope = new_scope(nil)
	for _, d := range file.Decls {
		anonymify_ast(d, 0, f.filescope)
	}
	f.packages = collect_package_imports(f.name, file.Decls, f.context)
	f.decls = make(map[string]*decl, len(file.Decls))
	for _, decl := range file.Decls {
		append_to_top_decls(f.decls, decl, f.filescope)
	}
}

func append_to_top_decls(decls map[string]*decl, decl ast.Decl, scope *scope) {
	foreach_decl(decl, func(data *foreach_decl_struct) {
		class := ast_decl_class(data.decl)
		for i, name := range data.names {
			typ, v, vi := data.type_value_index(i)

			d := new_decl_full(name.Name, class, 0, typ, v, vi, scope)
			if d == nil {
				return
			}

			methodof := method_of(decl)
			if methodof != "" {
				decl, ok := decls[methodof]
				if ok {
					decl.add_child(d)
				} else {
					decl = new_decl(methodof, decl_methods_stub, scope)
					decls[methodof] = decl
					decl.add_child(d)
				}
			} else {
				decl, ok := decls[d.name]
				if ok {
					decl.expand_or_replace(d)
				} else {
					decls[d.name] = d
				}
			}
		}
	})
}

func abs_path_for_package(filename, p string, context build.Context) (string, bool) {
	dir, _ := filepath.Split(filename)
	if len(p) == 0 {
		return "", false
	}
	if p[0] == '.' {
		return fmt.Sprintf("%s.a", filepath.Join(dir, p)), true
	}
	pkg, ok := find_go_dag_package(p, dir)
	if ok {
		return pkg, true
	}
	return find_global_file(p, context)
}

func path_and_alias(imp *ast.ImportSpec) (string, string) {
	path := ""
	if imp.Path != nil {
		path = string(imp.Path.Value)
		path = path[1 : len(path)-1]
	}
	alias := ""
	if imp.Name != nil {
		alias = imp.Name.Name
	}
	return path, alias
}

func find_go_dag_package(imp, filedir string) (string, bool) {
	// Support godag directory structure
	dir, pkg := filepath.Split(imp)
	godag_pkg := filepath.Join(filedir, "..", dir, "_obj", pkg+".a")
	if file_exists(godag_pkg) {
		return godag_pkg, true
	}
	return "", false
}

// autobuild compares the mod time of the source files of the package, and if any of them is newer
// than the package object file will rebuild it.
func autobuild(p *build.Package) error {
	if p.Dir == "" {
		return fmt.Errorf("no files to build")
	}
	ps, err := os.Stat(p.PkgObj)
	if err != nil {
		// Assume package file does not exist and build for the first time.
		return build_package(p)
	}
	pt := ps.ModTime()
	fs, err := readdir(p.Dir)
	if err != nil {
		return err
	}
	for _, f := range fs {
		if f.IsDir() {
			continue
		}
		if f.ModTime().After(pt) {
			// Source file is newer than package file; rebuild.
			return build_package(p)
		}
	}
	return nil
}

// build_package builds the package by calling `go install package/import`. If everything compiles
// correctly, the newly compiled package should then be in the usual place in the `$GOPATH/pkg`
// directory, and gocode will pick it up from there.
func build_package(p *build.Package) error {
	if *g_debug {
		log.Printf("-------------------")
		log.Printf("rebuilding package %s", p.Name)
		log.Printf("package import: %s", p.ImportPath)
		log.Printf("package object: %s", p.PkgObj)
		log.Printf("package source dir: %s", p.Dir)
		log.Printf("package source files: %v", p.GoFiles)
	}
	// TODO: Should read STDERR rather than STDOUT.
	out, err := exec.Command("go", "install", p.ImportPath).Output()
	if err != nil {
		return err
	}
	if *g_debug {
		log.Printf("build out: %s\n", string(out))
	}
	return nil
}

func log_found_package_maybe(imp, pkgpath string) {
	if *g_debug {
		log.Printf("Found %q at %q\n", imp, pkgpath)
	}
}

func log_build_context(context build.Context) {
	log.Printf(" GOROOT: %s\n", context.GOROOT)
	log.Printf(" GOPATH: %s\n", context.GOPATH)
	log.Printf(" GOOS: %s\n", context.GOOS)
	log.Printf(" GOARCH: %s\n", context.GOARCH)
	log.Printf(" lib-path: %q\n", g_config.LibPath)
}

// find_global_file returns the file path of the compiled package corresponding to the specified
// import, and a boolean stating whether such path is valid.
// TODO: Return only one value, possibly empty string if not found.
func find_global_file(imp string, context build.Context) (string, bool) {
	// gocode synthetically generates the builtin package
	// "unsafe", since the "unsafe.a" package doesn't really exist.
	// Thus, when the user request for the package "unsafe" we
	// would return synthetic global file that would be used
	// just as a key name to find this synthetic package
	if imp == "unsafe" {
		return "unsafe", true
	}

	pkgfile := fmt.Sprintf("%s.a", imp)

	// if lib-path is defined, use it
	if g_config.LibPath != "" {
		for _, p := range filepath.SplitList(g_config.LibPath) {
			pkg_path := filepath.Join(p, pkgfile)
			if file_exists(pkg_path) {
				log_found_package_maybe(imp, pkg_path)
				return pkg_path, true
			}
			// Also check the relevant pkg/OS_ARCH dir for the libpath, if provided.
			pkgdir := fmt.Sprintf("%s_%s", context.GOOS, context.GOARCH)
			pkg_path = filepath.Join(p, "pkg", pkgdir, pkgfile)
			if file_exists(pkg_path) {
				log_found_package_maybe(imp, pkg_path)
				return pkg_path, true
			}
		}
	}

	p, err := context.Import(imp, "", build.AllowBinary|build.FindOnly)
	if err == nil {
		if g_config.Autobuild {
			err = autobuild(p)
			if err != nil && *g_debug {
				log.Printf("Autobuild error: %s\n", err)
			}
		}
		if file_exists(p.PkgObj) {
			log_found_package_maybe(imp, p.PkgObj)
			return p.PkgObj, true
		}
	}

	if *g_debug {
		log.Printf("Import path %q was not resolved\n", imp)
		log.Println("Gocode's build context is:")
		log_build_context(context)
	}
	return "", false
}

func package_name(file *ast.File) string {
	if file.Name != nil {
		return file.Name.Name
	}
	return ""
}

//-------------------------------------------------------------------------
// decl_cache
//
// Thread-safe collection of DeclFileCache entities.
//-------------------------------------------------------------------------

type decl_cache struct {
	cache   map[string]*decl_file_cache
	context build.Context
	sync.Mutex
}

func new_decl_cache(context build.Context) *decl_cache {
	return &decl_cache{
		cache:   make(map[string]*decl_file_cache),
		context: context,
	}
}

func (c *decl_cache) get(filename string) *decl_file_cache {
	c.Lock()
	defer c.Unlock()

	f, ok := c.cache[filename]
	if !ok {
		f = new_decl_file_cache(filename, c.context)
		c.cache[filename] = f
	}
	return f
}

func (c *decl_cache) get_and_update(filename string) *decl_file_cache {
	f := c.get(filename)
	f.update()
	return f
}
