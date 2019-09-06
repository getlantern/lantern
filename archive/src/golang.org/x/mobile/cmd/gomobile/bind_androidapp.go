// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"archive/zip"
	"fmt"
	"go/build"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func goAndroidBind(pkgs []*build.Package, androidArchs []string) error {
	if sdkDir := os.Getenv("ANDROID_HOME"); sdkDir == "" {
		return fmt.Errorf("this command requires ANDROID_HOME environment variable (path to the Android SDK)")
	}
	var androidArgs []string
	if goVersion == go1_6 {
		// Ideally this would be -buildmode=c-shared.
		// https://golang.org/issue/13234.
		androidArgs = []string{"-gcflags=-shared", "-ldflags=-shared"}
	}

	paths := make([]string, len(pkgs))
	for i, p := range pkgs {
		paths[i] = p.ImportPath
	}

	androidDir := filepath.Join(tmpdir, "android")
	mainFile := filepath.Join(tmpdir, "androidlib/main.go")

	// Generate binding code and java source code only when processing the first package.
	first := true
	for _, arch := range androidArchs {
		env := androidEnv[arch]
		toolchain := ndk.Toolchain(arch)

		if !first {
			if err := goInstall(paths, env, androidArgs...); err != nil {
				return err
			}
			err := goBuild(
				mainFile,
				env,
				"-buildmode=c-shared",
				"-o="+filepath.Join(androidDir, "src/main/jniLibs/"+toolchain.abi+"/libgojni.so"),
			)
			if err != nil {
				return err
			}

			continue
		}
		first = false

		typesPkgs, err := loadExportData(pkgs, env, androidArgs...)
		if err != nil {
			return fmt.Errorf("loadExportData failed %v", err)
		}

		binder, err := newBinder(typesPkgs)
		if err != nil {
			return err
		}

		srcDir := filepath.Join(tmpdir, "gomobile_bind")
		for _, pkg := range binder.pkgs {
			if err := binder.GenGo(pkg, binder.pkgs, srcDir); err != nil {
				return err
			}
		}

		err = writeFile(mainFile, func(w io.Writer) error {
			_, err := w.Write(androidMainFile)
			return err
		})
		if err != nil {
			return fmt.Errorf("failed to create the main package for android: %v", err)
		}

		p, err := ctx.Import("golang.org/x/mobile/bind", cwd, build.ImportComment)
		if err != nil {
			return fmt.Errorf(`"golang.org/x/mobile/bind" is not found; run go get golang.org/x/mobile/bind`)
		}
		repo := filepath.Clean(filepath.Join(p.Dir, "..")) // golang.org/x/mobile directory.

		for _, pkg := range binder.pkgs {
			pkgpath := strings.Replace(bindJavaPkg, ".", "/", -1)
			if bindJavaPkg == "" {
				pkgpath = "go/" + pkg.Name()
			}
			if err := binder.GenJava(pkg, binder.pkgs, srcDir, filepath.Join(androidDir, "src/main/java/"+pkgpath)); err != nil {
				return err
			}
		}
		if err := binder.GenJavaSupport(srcDir); err != nil {
			return err
		}
		if err := binder.GenGoSupport(srcDir); err != nil {
			return err
		}

		javaDir := filepath.Join(androidDir, "src/main/java/go")
		if err := mkdir(javaDir); err != nil {
			return err
		}
		err = goBuild(
			mainFile,
			env,
			"-buildmode=c-shared",
			"-o="+filepath.Join(androidDir, "src/main/jniLibs/"+toolchain.abi+"/libgojni.so"),
		)
		if err != nil {
			return err
		}

		for _, javaFile := range []string{"Seq.java", "LoadJNI.java"} {
			src := filepath.Join(repo, "bind/java/"+javaFile)
			dst := filepath.Join(javaDir, javaFile)
			rm(dst)
			if err := symlink(src, dst); err != nil {
				return err
			}
		}
	}

	return buildAAR(androidDir, pkgs, androidArchs)
}

var androidMainFile = []byte(`
package main

import (
	_ "golang.org/x/mobile/bind/java"
	_ "../gomobile_bind"
)

func main() {}
`)

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
func buildAAR(androidDir string, pkgs []*build.Package, androidArchs []string) (err error) {
	var out io.Writer = ioutil.Discard
	if buildO == "" {
		buildO = pkgs[0].Name + ".aar"
	}
	if !strings.HasSuffix(buildO, ".aar") {
		return fmt.Errorf("output file name %q does not end in '.aar'", buildO)
	}
	if !buildN {
		f, err := os.Create(buildO)
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
	const manifestFmt = `<manifest xmlns:android="http://schemas.android.com/apk/res/android" package=%q>
<uses-sdk android:minSdkVersion="%d"/></manifest>`
	fmt.Fprintf(w, manifestFmt, "go."+pkgs[0].Name+".gojni", minAndroidAPI)

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

	files := map[string]string{}
	for _, pkg := range pkgs {
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
					if orig, exists := files[name]; exists {
						return fmt.Errorf("package %s asset name conflict: %s already added from package %s",
							pkg.ImportPath, name, orig)
					}
					files[name] = pkg.ImportPath
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
	}

	for _, arch := range androidArchs {
		toolchain := ndk.Toolchain(arch)
		lib := toolchain.abi + "/libgojni.so"
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
	minAndroidAPI  = 15
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

	javac := exec.Command("javac", args...)
	javac.Dir = srcDir
	if err := runCmd(javac); err != nil {
		return err
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
