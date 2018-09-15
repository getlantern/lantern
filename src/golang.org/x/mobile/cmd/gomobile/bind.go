// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"go/ast"
	"go/build"
	"go/importer"
	"go/token"
	"go/types"
	"io"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"strings"

	"golang.org/x/mobile/bind"
)

// ctx, pkg, tmpdir in build.go

var cmdBind = &command{
	run:   runBind,
	Name:  "bind",
	Usage: "[-target android|ios] [-o output] [build flags] [package]",
	Short: "build a library for Android and iOS",
	Long: `
Bind generates language bindings for the package named by the import
path, and compiles a library for the named target system.

The -target flag takes a target system name, either android (the
default) or ios.

For -target android, the bind command produces an AAR (Android ARchive)
file that archives the precompiled Java API stub classes, the compiled
shared libraries, and all asset files in the /assets subdirectory under
the package directory. The output is named '<package_name>.aar' by
default. This AAR file is commonly used for binary distribution of an
Android library project and most Android IDEs support AAR import. For
example, in Android Studio (1.2+), an AAR file can be imported using
the module import wizard (File > New > New Module > Import .JAR or
.AAR package), and setting it as a new dependency
(File > Project Structure > Dependencies).  This requires 'javac'
(version 1.7+) and Android SDK (API level 9 or newer) to build the
library for Android. The environment variable ANDROID_HOME must be set
to the path to Android SDK. The generated Java class is in the java
package 'go.<package_name>' unless -javapkg flag is specified.

For -target ios, gomobile must be run on an OS X machine with Xcode
installed. Support is not complete. The generated Objective-C types
are prefixed with 'Go' unless the -prefix flag is provided.

The -v flag provides verbose output, including the list of packages built.

The build flags -a, -n, -x, -gcflags, -ldflags, -tags, and -work
are shared with the build command. For documentation, see 'go help build'.
`,
}

func runBind(cmd *command) error {
	cleanup, err := buildEnvInit()
	if err != nil {
		return err
	}
	defer cleanup()

	args := cmd.flag.Args()

	targetOS, targetArchs, err := parseBuildTarget(buildTarget)
	if err != nil {
		return fmt.Errorf(`invalid -target=%q: %v`, buildTarget, err)
	}

	ctx.GOARCH = "arm"
	ctx.GOOS = targetOS

	if bindJavaPkg != "" && ctx.GOOS != "android" {
		return fmt.Errorf("-javapkg is supported only for android target")
	}
	if bindPrefix != "" && ctx.GOOS != "darwin" {
		return fmt.Errorf("-prefix is supported only for ios target")
	}

	var pkgs []*build.Package
	switch len(args) {
	case 0:
		pkgs = make([]*build.Package, 1)
		pkgs[0], err = ctx.ImportDir(cwd, build.ImportComment)
	default:
		pkgs, err = importPackages(args)
	}
	if err != nil {
		return err
	}

	// check if any of the package is main
	for _, pkg := range pkgs {
		if pkg.Name == "main" {
			return fmt.Errorf("binding 'main' package (%s) is not supported", pkg.ImportComment)
		}
	}

	switch targetOS {
	case "android":
		return goAndroidBind(pkgs, targetArchs)
	case "darwin":
		// TODO: use targetArchs?
		return goIOSBind(pkgs)
	default:
		return fmt.Errorf(`invalid -target=%q`, buildTarget)
	}
}

func importPackages(args []string) ([]*build.Package, error) {
	pkgs := make([]*build.Package, len(args))
	for i, path := range args {
		var err error
		if pkgs[i], err = ctx.Import(path, cwd, build.ImportComment); err != nil {
			return nil, fmt.Errorf("package %q: %v", path, err)
		}
	}
	return pkgs, nil
}

var (
	bindPrefix  string // -prefix
	bindJavaPkg string // -javapkg
)

func init() {
	// bind command specific commands.
	cmdBind.flag.StringVar(&bindJavaPkg, "javapkg", "",
		"specifies custom Java package path used instead of the default 'go.<go package name>'. Valid only with -target=android.")
	cmdBind.flag.StringVar(&bindPrefix, "prefix", "",
		"custom Objective-C name prefix used instead of the default 'Go'. Valid only with -lang=ios.")
}

type binder struct {
	files []*ast.File
	fset  *token.FileSet
	pkgs  []*types.Package
}

func (b *binder) GenGoSupport(outdir string) error {
	bindPkg, err := ctx.Import("golang.org/x/mobile/bind", "", build.FindOnly)
	if err != nil {
		return err
	}
	return copyFile(filepath.Join(outdir, "seq.go"), filepath.Join(bindPkg.Dir, "seq.go.support"))
}

func (b *binder) GenObjcSupport(outdir string) error {
	objcPkg, err := ctx.Import("golang.org/x/mobile/bind/objc", "", build.FindOnly)
	if err != nil {
		return err
	}
	if err := copyFile(filepath.Join(outdir, "seq_darwin.m"), filepath.Join(objcPkg.Dir, "seq_darwin.m.support")); err != nil {
		return err
	}
	if err := copyFile(filepath.Join(outdir, "seq_darwin.go"), filepath.Join(objcPkg.Dir, "seq_darwin.go.support")); err != nil {
		return err
	}
	return copyFile(filepath.Join(outdir, "seq.h"), filepath.Join(objcPkg.Dir, "seq.h"))
}

func (b *binder) GenObjc(pkg *types.Package, allPkg []*types.Package, outdir string) (string, error) {
	const bindPrefixDefault = "Go"
	if bindPrefix == "" {
		bindPrefix = bindPrefixDefault
	}
	name := strings.Title(pkg.Name())
	bindOption := "-lang=objc"
	if bindPrefix != bindPrefixDefault {
		bindOption += " -prefix=" + bindPrefix
	}

	fileBase := bindPrefix + name
	mfile := filepath.Join(outdir, fileBase+".m")
	hfile := filepath.Join(outdir, fileBase+".h")
	gohfile := filepath.Join(outdir, pkg.Name()+".h")

	conf := &bind.GeneratorConfig{
		Fset:   b.fset,
		Pkg:    pkg,
		AllPkg: allPkg,
	}
	generate := func(w io.Writer) error {
		if buildX {
			printcmd("gobind %s -outdir=%s %s", bindOption, outdir, pkg.Path())
		}
		if buildN {
			return nil
		}
		conf.Writer = w
		return bind.GenObjc(conf, bindPrefix, bind.ObjcM)
	}
	if err := writeFile(mfile, generate); err != nil {
		return "", err
	}
	generate = func(w io.Writer) error {
		if buildN {
			return nil
		}
		conf.Writer = w
		return bind.GenObjc(conf, bindPrefix, bind.ObjcH)
	}
	if err := writeFile(hfile, generate); err != nil {
		return "", err
	}
	generate = func(w io.Writer) error {
		if buildN {
			return nil
		}
		conf.Writer = w
		return bind.GenObjc(conf, bindPrefix, bind.ObjcGoH)
	}
	if err := writeFile(gohfile, generate); err != nil {
		return "", err
	}

	return fileBase, nil
}

func (b *binder) GenJavaSupport(outdir string) error {
	javaPkg, err := ctx.Import("golang.org/x/mobile/bind/java", "", build.FindOnly)
	if err != nil {
		return err
	}
	if err := copyFile(filepath.Join(outdir, "seq_android.go"), filepath.Join(javaPkg.Dir, "seq_android.go.support")); err != nil {
		return err
	}
	if err := copyFile(filepath.Join(outdir, "seq_android.c"), filepath.Join(javaPkg.Dir, "seq_android.c.support")); err != nil {
		return err
	}
	return copyFile(filepath.Join(outdir, "seq.h"), filepath.Join(javaPkg.Dir, "seq.h"))
}

func (b *binder) GenJava(pkg *types.Package, allPkg []*types.Package, outdir, javadir string) error {
	className := strings.Title(pkg.Name())
	javaFile := filepath.Join(javadir, className+".java")
	cFile := filepath.Join(outdir, "java_"+pkg.Name()+".c")
	hFile := filepath.Join(outdir, pkg.Name()+".h")
	bindOption := "-lang=java"
	if bindJavaPkg != "" {
		bindOption += " -javapkg=" + bindJavaPkg
	}

	conf := &bind.GeneratorConfig{
		Fset:   b.fset,
		Pkg:    pkg,
		AllPkg: allPkg,
	}
	generate := func(w io.Writer) error {
		if buildX {
			printcmd("gobind %s -outdir=%s %s", bindOption, javadir, pkg.Path())
		}
		if buildN {
			return nil
		}
		conf.Writer = w
		return bind.GenJava(conf, bindJavaPkg, bind.Java)
	}
	if err := writeFile(javaFile, generate); err != nil {
		return err
	}
	generate = func(w io.Writer) error {
		if buildN {
			return nil
		}
		conf.Writer = w
		return bind.GenJava(conf, bindJavaPkg, bind.JavaC)
	}
	if err := writeFile(cFile, generate); err != nil {
		return err
	}
	generate = func(w io.Writer) error {
		if buildN {
			return nil
		}
		conf.Writer = w
		return bind.GenJava(conf, bindJavaPkg, bind.JavaH)
	}
	return writeFile(hFile, generate)
}

func (b *binder) GenGo(pkg *types.Package, allPkg []*types.Package, outdir string) error {
	pkgName := "go_" + pkg.Name()
	goFile := filepath.Join(outdir, pkgName+"main.go")

	generate := func(w io.Writer) error {
		if buildX {
			printcmd("gobind -lang=go -outdir=%s %s", outdir, pkg.Path())
		}
		if buildN {
			return nil
		}
		conf := &bind.GeneratorConfig{
			Writer: w,
			Fset:   b.fset,
			Pkg:    pkg,
			AllPkg: allPkg,
		}
		return bind.GenGo(conf)
	}
	if err := writeFile(goFile, generate); err != nil {
		return err
	}
	return nil
}

func copyFile(dst, src string) error {
	if buildX {
		printcmd("cp %s %s", src, dst)
	}
	return writeFile(dst, func(w io.Writer) error {
		if buildN {
			return nil
		}
		f, err := os.Open(src)
		if err != nil {
			return err
		}
		defer f.Close()

		if _, err := io.Copy(w, f); err != nil {
			return fmt.Errorf("cp %s %s failed: %v", src, dst, err)
		}
		return nil
	})
}

func writeFile(filename string, generate func(io.Writer) error) error {
	if buildV {
		fmt.Fprintf(os.Stderr, "write %s\n", filename)
	}

	err := mkdir(filepath.Dir(filename))
	if err != nil {
		return err
	}

	if buildN {
		return generate(ioutil.Discard)
	}

	f, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer func() {
		if cerr := f.Close(); err == nil {
			err = cerr
		}
	}()

	return generate(f)
}

func loadExportData(pkgs []*build.Package, env []string, args ...string) ([]*types.Package, error) {
	// Compile the package. This will produce good errors if the package
	// doesn't typecheck for some reason, and is a necessary step to
	// building the final output anyway.
	paths := make([]string, len(pkgs))
	for i, p := range pkgs {
		paths[i] = p.ImportPath
	}
	if err := goInstall(paths, env, args...); err != nil {
		return nil, err
	}

	goos, goarch := getenv(env, "GOOS"), getenv(env, "GOARCH")

	// Assemble a fake GOPATH and trick go/importer into using it.
	// Ideally the importer package would let us provide this to
	// it somehow, but this works with what's in Go 1.5 today and
	// gives us access to the gcimporter package without us having
	// to make a copy of it.
	fakegopath := filepath.Join(tmpdir, "fakegopath")
	if err := removeAll(fakegopath); err != nil {
		return nil, err
	}
	if err := mkdir(filepath.Join(fakegopath, "pkg")); err != nil {
		return nil, err
	}
	typePkgs := make([]*types.Package, len(pkgs))
	imp := importer.Default()
	for i, p := range pkgs {
		importPath := p.ImportPath
		src := filepath.Join(pkgdir(env), importPath+".a")
		dst := filepath.Join(fakegopath, "pkg/"+goos+"_"+goarch+"/"+importPath+".a")
		if err := copyFile(dst, src); err != nil {
			return nil, err
		}
		if buildN {
			typePkgs[i] = types.NewPackage(importPath, path.Base(importPath))
			continue
		}
		oldDefault := build.Default
		build.Default = ctx // copy
		build.Default.GOARCH = goarch
		build.Default.GOPATH = fakegopath
		p, err := imp.Import(importPath)
		build.Default = oldDefault
		if err != nil {
			return nil, err
		}
		typePkgs[i] = p
	}
	return typePkgs, nil
}

func newBinder(pkgs []*types.Package) (*binder, error) {
	for _, pkg := range pkgs {
		if pkg.Name() == "main" {
			return nil, fmt.Errorf("package %q (%q): can only bind a library package", pkg.Name(), pkg.Path())
		}
	}
	b := &binder{
		fset: token.NewFileSet(),
		pkgs: pkgs,
	}
	return b, nil
}
