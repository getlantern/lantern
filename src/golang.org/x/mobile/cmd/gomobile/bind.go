// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/scanner"
	"go/token"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"
	"unicode"
	"unicode/utf8"

	"golang.org/x/mobile/bind"
	"golang.org/x/tools/go/loader"
	"golang.org/x/tools/go/types"
)

// ctx, pkg, ndkccpath, tmpdir in build.go

var cmdBind = &command{
	run:   runBind,
	Name:  "bind",
	Usage: "[package]",
	Short: "build a shared library for android APK and iOS app",
	Long: `
Bind generates language bindings like gobind (golang.org/x/mobile/cmd/gobind)
for a package and builds a shared library for each platform from the go binding
code.

For Android, the bind command produces an AAR (Android ARchive) file that
archives the precompiled Java API stub classes, the compiled shared libraries,
and all asset files in the /assets subdirectory under the package directory.
The output AAR file name is '<package_name>.aar'.

The AAR file is commonly used for binary distribution of an Android library
project and most Android IDEs support AAR import. For example, in Android
Studio (1.2+), an AAR file can be imported using the module import wizard
(File > New > New Module > Import .JAR or .AAR package), and setting it as
a new dependency (File > Project Structure > Dependencies).

This command requires 'javac' (version 1.7+) and Android SDK (API level 9
or newer) to build the library for Android. The environment variable
ANDROID_HOME must be set to the path to Android SDK.

The -v flag provides verbose output, including the list of packages built.

These build flags are shared by the build command.
For documentation, see 'go help build':
	-a
	-i
	-n
	-x
	-tags 'tag list'
`,
}

// TODO: -mobile
// TODO: reuse the -o option to specify the output file name?

func runBind(cmd *command) error {
	cwd, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	args := cmd.flag.Args()

	var bindPkg *build.Package
	switch len(args) {
	case 0:
		bindPkg, err = ctx.ImportDir(cwd, build.ImportComment)
	case 1:
		bindPkg, err = ctx.Import(args[0], cwd, build.ImportComment)
	default:
		cmd.usage()
		os.Exit(1)
	}
	if err != nil {
		return err
	}

	if sdkDir := os.Getenv("ANDROID_HOME"); sdkDir == "" {
		return fmt.Errorf("this command requires ANDROID_HOME environment variable (path to the Android SDK)")
	}

	if buildN {
		tmpdir = "$WORK"
	} else {
		tmpdir, err = ioutil.TempDir("", "gomobile-bind-work-")
		if err != nil {
			return err
		}
	}
	defer removeAll(tmpdir)
	if buildX {
		fmt.Fprintln(os.Stderr, "WORK="+tmpdir)
	}

	binder, err := newBinder(bindPkg)
	if err != nil {
		return err
	}

	if err := binder.GenGo(tmpdir); err != nil {
		return err
	}

	mainFile := filepath.Join(tmpdir, "androidlib/main.go")
	err = writeFile(mainFile, func(w io.Writer) error {
		return androidMainTmpl.Execute(w, "../go_"+binder.pkg.Name())
	})
	if err != nil {
		return fmt.Errorf("failed to create the main package for android: %v", err)
	}

	androidDir := filepath.Join(tmpdir, "android")

	err = goAndroidBuild(mainFile, filepath.Join(androidDir, "src/main/jniLibs/armeabi-v7a/libgojni.so"))
	if err != nil {
		return err
	}

	p, err := ctx.Import("golang.org/x/mobile/app", cwd, build.ImportComment)
	if err != nil {
		return fmt.Errorf(`"golang.org/x/mobile/app" is not found; run go get golang.org/x/mobile/app`)
	}
	repo := filepath.Clean(filepath.Join(p.Dir, "..")) // golang.org/x/mobile directory.

	// TODO(crawshaw): use a better package path derived from the go package.
	if err := binder.GenJava(filepath.Join(androidDir, "src/main/java/go/"+binder.pkg.Name())); err != nil {
		return err
	}

	src := filepath.Join(repo, "app/Go.java")
	dst := filepath.Join(androidDir, "src/main/java/go/Go.java")
	rm(dst)
	if err := symlink(src, dst); err != nil {
		return err
	}

	src = filepath.Join(repo, "bind/java/Seq.java")
	dst = filepath.Join(androidDir, "src/main/java/go/Seq.java")
	rm(dst)
	if err := symlink(src, dst); err != nil {
		return err
	}

	return buildAAR(androidDir, bindPkg)
}

type binder struct {
	files []*ast.File
	fset  *token.FileSet
	pkg   *types.Package
}

func (b *binder) GenJava(outdir string) error {
	firstRune, size := utf8.DecodeRuneInString(b.pkg.Name())
	className := string(unicode.ToUpper(firstRune)) + b.pkg.Name()[size:]
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
	goFile := filepath.Join(outdir, pkgName, pkgName+".go")

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

	if len(bindPkg.CgoFiles) > 0 {
		return nil, fmt.Errorf("cannot use cgo-dependent package as service definition: %s", bindPkg.CgoFiles[0])
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
		Fset: fset,
	}
	conf.TypeChecker.Error = func(err error) {
		fmt.Fprintln(os.Stderr, err)
	}

	conf.CreateFromFiles(bindPkg.ImportPath, files...)
	program, err := conf.Load()
	if err != nil {
		return nil, err
	}
	b := &binder{
		files: files,
		fset:  fset,
		pkg:   program.Created[0].Pkg,
	}
	return b, nil
}

var androidMainTmpl = template.Must(template.New("android.go").Parse(`
package main

import (
	"golang.org/x/mobile/app"
	"golang.org/x/mobile/bind/java"

	_ "{{.}}"
)

func main() {
	app.Run(app.Callbacks{Start: java.Init})
}
`))

// AAR is the format for the binary distribution of an Android Library Project
// and it is a ZIP archive with extension .aar.
// http://tools.android.com/tech-docs/new-build-system/aar-format
//
// These entries are directly at the root of the archive.
//
//	AndroidManifest.xml (mandatory)
// 	classes.jar (mandatory)
//	assets/ (optional)
//	jni/<abi>/libgojni.so
//	R.txt (mandatory)
//	res/ (mandatory)
//	libs/*.jar (optional, not relevant)
//	proguard.txt (optional)
//	lint.jar (optional, not relevant)
//	aidl (optional, not relevant)
//
// javac and jar commands are needed to build classes.jar.
func buildAAR(androidDir string, pkg *build.Package) (err error) {
	var out io.Writer = ioutil.Discard
	if !buildN {
		f, err := os.Create(pkg.Name + ".aar")
		if err != nil {
			return err
		}
		defer func() {
			if cerr := f.Close(); err == nil {
				err = cerr
			}
		}()
		out = f
	}

	aarw := zip.NewWriter(out)
	aarwcreate := func(name string) (io.Writer, error) {
		if buildV {
			fmt.Fprintf(os.Stderr, "aar: %s\n", name)
		}
		return aarw.Create(name)
	}
	w, err := aarwcreate("AndroidManifest.xml")
	if err != nil {
		return err
	}
	const manifestFmt = `<manifest xmlns:android="http://schemas.android.com/apk/res/android" package=%q />`
	fmt.Fprintf(w, manifestFmt, "go."+pkg.Name+".gojni")

	w, err = aarwcreate("proguard.txt")
	if err != nil {
		return err
	}
	fmt.Fprintln(w, `-keep class go.** { *; }`)

	w, err = aarwcreate("classes.jar")
	if err != nil {
		return err
	}
	src := filepath.Join(androidDir, "src/main/java")
	if err := buildJar(w, src); err != nil {
		return err
	}

	assetsDir := filepath.Join(pkg.Dir, "assets")
	assetsDirExists := false
	if fi, err := os.Stat(assetsDir); err == nil {
		assetsDirExists = fi.IsDir()
	} else if !os.IsNotExist(err) {
		return err
	}

	if assetsDirExists {
		err := filepath.Walk(
			assetsDir, func(path string, info os.FileInfo, err error) error {
				if err != nil {
					return err
				}
				if info.IsDir() {
					return nil
				}
				f, err := os.Open(path)
				if err != nil {
					return err
				}
				defer f.Close()
				name := "assets/" + path[len(assetsDir)+1:]
				w, err := aarwcreate(name)
				if err != nil {
					return nil
				}
				_, err = io.Copy(w, f)
				return err
			})
		if err != nil {
			return err
		}
	}

	lib := "armeabi-v7a/libgojni.so"
	w, err = aarwcreate("jni/" + lib)
	if err != nil {
		return err
	}
	if !buildN {
		r, err := os.Open(filepath.Join(androidDir, "src/main/jniLibs/"+lib))
		if err != nil {
			return err
		}
		defer r.Close()
		if _, err := io.Copy(w, r); err != nil {
			return err
		}
	}

	// TODO(hyangah): do we need to use aapt to create R.txt?
	w, err = aarwcreate("R.txt")
	if err != nil {
		return err
	}

	w, err = aarwcreate("res/")
	if err != nil {
		return err
	}

	return aarw.Close()
}

const (
	javacTargetVer = "1.7"
	minAndroidAPI  = 9
)

func buildJar(w io.Writer, srcDir string) error {
	var srcFiles []string
	if buildN {
		srcFiles = []string{"*.java"}
	} else {
		err := filepath.Walk(srcDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if filepath.Ext(path) == ".java" {
				srcFiles = append(srcFiles, filepath.Join(".", path[len(srcDir):]))
			}
			return nil
		})
		if err != nil {
			return err
		}
	}

	dst := filepath.Join(tmpdir, "javac-output")
	if !buildN {
		if err := os.MkdirAll(dst, 0700); err != nil {
			return err
		}
	}
	defer removeAll(dst)

	apiPath, err := androidAPIPath()
	if err != nil {
		return err
	}

	args := []string{
		"-d", dst,
		"-source", javacTargetVer,
		"-target", javacTargetVer,
		"-bootclasspath", filepath.Join(apiPath, "android.jar"),
	}
	args = append(args, srcFiles...)

	buf := new(bytes.Buffer)
	javac := exec.Command("javac", args...)
	javac.Dir = srcDir
	if buildV {
		javac.Stdout = os.Stdout
		javac.Stderr = os.Stderr
	} else {
		javac.Stdout = buf
		javac.Stderr = buf
	}
	if buildX {
		printcmd("%s", strings.Join(javac.Args, " "))
	}
	if !buildN {
		if err := javac.Run(); err != nil {
			buf.WriteTo(xout)
			return err
		}
	}

	if buildX {
		printcmd("jar c -C %s .", dst)
	}
	if buildN {
		return nil
	}

	jarw := zip.NewWriter(w)
	jarwcreate := func(name string) (io.Writer, error) {
		if buildV {
			fmt.Fprintf(os.Stderr, "jar: %s\n", name)
		}
		return jarw.Create(name)
	}
	f, err := jarwcreate("META-INF/MANIFEST.MF")
	if err != nil {
		return err
	}
	fmt.Fprintf(f, manifestHeader)

	err = filepath.Walk(dst, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		out, err := jarwcreate(filepath.ToSlash(path[len(dst)+1:]))
		if err != nil {
			return err
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		_, err = io.Copy(out, in)
		return err
	})
	if err != nil {
		return err
	}
	return jarw.Close()
}

// androidAPIPath returns an android SDK platform directory under ANDROID_HOME.
// If there are multiple platforms that satisfy the minimum version requirement
// androidAPIPath returns the latest one among them.
func androidAPIPath() (string, error) {
	sdk := os.Getenv("ANDROID_HOME")
	if sdk == "" {
		return "", fmt.Errorf("ANDROID_HOME environment var is not set")
	}
	sdkDir, err := os.Open(filepath.Join(sdk, "platforms"))
	if err != nil {
		return "", fmt.Errorf("failed to find android SDK platform: %v", err)
	}
	defer sdkDir.Close()
	fis, err := sdkDir.Readdir(-1)
	if err != nil {
		return "", fmt.Errorf("failed to find android SDK platform (min API level: %d): %v", minAndroidAPI, err)
	}

	var apiPath string
	var apiVer int
	for _, fi := range fis {
		name := fi.Name()
		if !fi.IsDir() || !strings.HasPrefix(name, "android-") {
			continue
		}
		n, err := strconv.Atoi(name[len("android-"):])
		if err != nil || n < minAndroidAPI {
			continue
		}
		p := filepath.Join(sdkDir.Name(), name)
		_, err = os.Stat(filepath.Join(p, "android.jar"))
		if err == nil && apiVer < n {
			apiPath = p
			apiVer = n
		}
	}
	if apiVer == 0 {
		return "", fmt.Errorf("failed to find android SDK platform (min API level: %d) in %s",
			minAndroidAPI, sdkDir.Name())
	}
	return apiPath, nil
}
