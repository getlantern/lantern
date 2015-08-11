// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"errors"
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/scanner"
	"go/token"
	"go/types"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/mobile/bind"
	"golang.org/x/mobile/internal/loader"
)

// ctx, pkg, tmpdir in build.go

var cmdBind = &command{
	run:   runBind,
	Name:  "bind",
	Usage: "[-target android|ios] [-o output] [build flags] [package]",
	Short: "build a shared library for android APK and iOS app",
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
to the path to Android SDK.

For -target ios, gomobile must be run on an OS X machine with Xcode
installed. Support is not complete.

The -v flag provides verbose output, including the list of packages built.

The build flags -a, -i, -n, -x, -gcflags, -ldflags, -tags, and -work
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

	ctx.GOARCH = "arm"
	switch buildTarget {
	case "android":
		ctx.GOOS = "android"
	case "ios":
		ctx.GOOS = "darwin"
	default:
		return fmt.Errorf(`unknown -target, %q.`, buildTarget)
	}

	var pkg *build.Package
	switch len(args) {
	case 0:
		pkg, err = ctx.ImportDir(cwd, build.ImportComment)
	case 1:
		pkg, err = ctx.Import(args[0], cwd, build.ImportComment)
	default:
		cmd.usage()
		os.Exit(1)
	}
	if err != nil {
		return err
	}

	switch buildTarget {
	case "android":
		return goAndroidBind(pkg)
	case "ios":
		return goIOSBind(pkg)
	default:
		return fmt.Errorf(`unknown -target, %q.`, buildTarget)
	}
}

type binder struct {
	files []*ast.File
	fset  *token.FileSet
	pkg   *types.Package
}

func (b *binder) GenObjc(outdir string) error {
	name := strings.Title(b.pkg.Name())
	mfile := filepath.Join(outdir, "Go"+name+".m")
	hfile := filepath.Join(outdir, "Go"+name+".h")

	if buildX {
		printcmd("gobind -lang=objc %s > %s", b.pkg.Path(), mfile)
	}

	generate := func(w io.Writer) error {
		return bind.GenObjc(w, b.fset, b.pkg, false)
	}
	if err := writeFile(mfile, generate); err != nil {
		return err
	}
	generate = func(w io.Writer) error {
		return bind.GenObjc(w, b.fset, b.pkg, true)
	}
	if err := writeFile(hfile, generate); err != nil {
		return err
	}

	objcPkg, err := ctx.Import("golang.org/x/mobile/bind/objc", "", build.FindOnly)
	if err != nil {
		return err
	}
	return copyFile(filepath.Join(outdir, "seq.h"), filepath.Join(objcPkg.Dir, "seq.h"))
}

func (b *binder) GenJava(outdir string) error {
	className := strings.Title(b.pkg.Name())
	javaFile := filepath.Join(outdir, className+".java")

	if buildX {
		printcmd("gobind -lang=java %s > %s", b.pkg.Path(), javaFile)
	}

	generate := func(w io.Writer) error {
		return bind.GenJava(w, b.fset, b.pkg)
	}
	if err := writeFile(javaFile, generate); err != nil {
		return err
	}
	return nil
}

func (b *binder) GenGo(outdir string) error {
	pkgName := "go_" + b.pkg.Name()
	goFile := filepath.Join(outdir, pkgName, pkgName+"main.go")

	if buildX {
		printcmd("gobind -lang=go %s > %s", b.pkg.Path(), goFile)
	}

	generate := func(w io.Writer) error {
		return bind.GenGo(w, b.fset, b.pkg)
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

func newBinder(bindPkg *build.Package) (*binder, error) {
	if bindPkg.Name == "main" {
		return nil, fmt.Errorf("package %q: can only bind a library package", bindPkg.Name)
	}

	fset := token.NewFileSet()

	hasErr := false
	var files []*ast.File
	for _, filename := range bindPkg.GoFiles {
		p := filepath.Join(bindPkg.Dir, filename)
		file, err := parser.ParseFile(fset, p, nil, parser.AllErrors)
		if err != nil {
			hasErr = true
			if list, _ := err.(scanner.ErrorList); len(list) > 0 {
				for _, err := range list {
					fmt.Fprintln(os.Stderr, err)
				}
			} else {
				fmt.Fprintln(os.Stderr, err)
			}
		}
		files = append(files, file)
	}

	if hasErr {
		return nil, errors.New("package parsing failed.")
	}

	conf := loader.Config{
		Fset:        fset,
		AllowErrors: true,
	}
	conf.TypeChecker.IgnoreFuncBodies = true
	conf.TypeChecker.FakeImportC = true
	conf.TypeChecker.DisableUnusedImportCheck = true
	var tcErrs []error
	conf.TypeChecker.Error = func(err error) {
		tcErrs = append(tcErrs, err)
	}

	conf.CreateFromFiles(bindPkg.ImportPath, files...)
	program, err := conf.Load()
	if err != nil {
		for _, err := range tcErrs {
			fmt.Fprintln(os.Stderr, err)
		}
		return nil, err
	}
	b := &binder{
		files: files,
		fset:  fset,
		pkg:   program.Created[0].Pkg,
	}
	return b, nil
}
