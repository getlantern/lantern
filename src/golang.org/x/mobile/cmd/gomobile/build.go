// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"go/build"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

var ctx = build.Default
var pkg *build.Package
var gomobilepath string // $GOPATH/pkg/gomobile
var ndkccpath string    // $GOPATH/pkg/gomobile/android-{{.NDK}}
var tmpdir string

var cmdBuild = &command{
	run:   runBuild,
	Name:  "build",
	Usage: "[-o output] [-i] [build flags] [package]",
	Short: "compile android APK and iOS app",
	Long: `
Build compiles and encodes the app named by the import path.

The named package must define a main function.

If an AndroidManifest.xml is defined in the package directory, it is
added to the APK file. Otherwise, a default manifest is generated.

If the package directory contains an assets subdirectory, its contents
are copied into the APK file.

The -o flag specifies the output file name. If not specified, the
output file name depends on the package built. The output file must end
in '.apk'.

The -v flag provides verbose output, including the list of packages built.

These build flags are shared by the build, install, and test commands.
For documentation, see 'go help build':
	-a
	-i
	-n
	-x
	-tags 'tag list'
`,
}

// TODO: -mobile

func runBuild(cmd *command) (err error) {
	cwd, err := os.Getwd()
	if err != nil {
		panic(err)
	}
	args := cmd.flag.Args()

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

	if pkg.Name != "main" {
		// Not an app, don't build a final package.
		return goAndroidBuild(pkg.ImportPath, "")
	}

	// Building a program, make sure it is appropriate for mobile.
	importsApp := false
	for _, path := range pkg.Imports {
		if path == "golang.org/x/mobile/app" {
			importsApp = true
			break
		}
	}
	if !importsApp {
		return fmt.Errorf(`%s does not import "golang.org/x/mobile/app"`, pkg.ImportPath)
	}

	if buildN {
		tmpdir = "$WORK"
	} else {
		tmpdir, err = ioutil.TempDir("", "gobuildapk-work-")
		if err != nil {
			return err
		}
	}
	defer removeAll(tmpdir)
	if buildX {
		fmt.Fprintln(os.Stderr, "WORK="+tmpdir)
	}

	libName := path.Base(pkg.ImportPath)
	manifestData, err := ioutil.ReadFile(filepath.Join(pkg.Dir, "AndroidManifest.xml"))
	if err != nil {
		if !os.IsNotExist(err) {
			return err
		}
		buf := new(bytes.Buffer)
		buf.WriteString(`<?xml version="1.0" encoding="utf-8"?>`)
		err := manifestTmpl.Execute(buf, manifestTmplData{
			// TODO(crawshaw): a better package path.
			JavaPkgPath: "org.golang.todo." + pkg.Name,
			Name:        strings.ToUpper(pkg.Name[:1]) + pkg.Name[1:],
			LibName:     libName,
		})
		if err != nil {
			return err
		}
		manifestData = buf.Bytes()
		if buildV {
			fmt.Fprintf(os.Stderr, "generated AndroidManifest.xml:\n%s\n", manifestData)
		}
	} else {
		libName, err = manifestLibName(manifestData)
		if err != nil {
			return err
		}
	}
	libPath := filepath.Join(tmpdir, "lib"+libName+".so")

	if err := goAndroidBuild(pkg.ImportPath, libPath); err != nil {
		return err
	}
	block, _ := pem.Decode([]byte(debugCert))
	if block == nil {
		return errors.New("no debug cert")
	}
	privKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return err
	}

	if *buildO == "" {
		*buildO = filepath.Base(pkg.Dir) + ".apk"
	}
	if !strings.HasSuffix(*buildO, ".apk") {
		return fmt.Errorf("output file name %q does not end in '.apk'", *buildO)
	}
	var out io.Writer
	if !buildN {
		f, err := os.Create(*buildO)
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

	var apkw *Writer
	if !buildN {
		apkw = NewWriter(out, privKey)
	}
	apkwcreate := func(name string) (io.Writer, error) {
		if buildV {
			fmt.Fprintf(os.Stderr, "apk: %s\n", name)
		}
		if buildN {
			return ioutil.Discard, nil
		}
		return apkw.Create(name)
	}

	w, err := apkwcreate("AndroidManifest.xml")
	if err != nil {
		return err
	}
	if _, err := w.Write(manifestData); err != nil {
		return err
	}

	w, err = apkwcreate("lib/armeabi/lib" + libName + ".so")
	if err != nil {
		return err
	}
	if !buildN {
		r, err := os.Open(libPath)
		if err != nil {
			return err
		}
		if _, err := io.Copy(w, r); err != nil {
			return err
		}
	}

	importsAudio := pkgImportsAudio(pkg)
	if importsAudio {
		alDir := filepath.Join(ndkccpath, "openal/lib")
		filepath.Walk(alDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if info.IsDir() {
				return nil
			}
			name := "lib/" + path[len(alDir)+1:]
			w, err := apkwcreate(name)
			if err != nil {
				return err
			}
			if !buildN {
				f, err := os.Open(path)
				if err != nil {
					return err
				}
				defer f.Close()
				_, err = io.Copy(w, f)
			}
			return err
		})
	}

	// Add any assets.
	assetsDir := filepath.Join(pkg.Dir, "assets")
	assetsDirExists := true
	fi, err := os.Stat(assetsDir)
	if err != nil {
		if os.IsNotExist(err) {
			assetsDirExists = false
		} else {
			return err
		}
	} else {
		assetsDirExists = fi.IsDir()
	}
	if assetsDirExists {
		filepath.Walk(assetsDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if info.IsDir() {
				return nil
			}
			name := "assets/" + path[len(assetsDir)+1:]
			w, err := apkwcreate(name)
			if err != nil {
				return err
			}
			f, err := os.Open(path)
			if err != nil {
				return err
			}
			defer f.Close()
			_, err = io.Copy(w, f)
			return err
		})
	}

	// TODO: add gdbserver to apk?

	if !buildN {
		if err := apkw.Close(); err != nil {
			return err
		}
	}

	return nil
}

var xout io.Writer = os.Stderr

func printcmd(format string, args ...interface{}) {
	cmd := fmt.Sprintf(format+"\n", args...)
	if tmpdir != "" {
		cmd = strings.Replace(cmd, tmpdir, "$WORK", -1)
	}
	if gomobilepath != "" {
		cmd = strings.Replace(cmd, gomobilepath, "$GOMOBILE", -1)
	}
	if goroot := goEnv("GOROOT"); goroot != "" {
		cmd = strings.Replace(cmd, goroot, "$GOROOT", -1)
	}
	if env := os.Getenv("HOME"); env != "" {
		cmd = strings.Replace(cmd, env, "$HOME", -1)
	}
	if env := os.Getenv("HOMEPATH"); env != "" {
		cmd = strings.Replace(cmd, env, "$HOMEPATH", -1)
	}
	fmt.Fprint(xout, cmd)
}

// "Build flags", used by multiple commands.
var (
	buildA bool    // -a
	buildI bool    // -i
	buildN bool    // -n
	buildV bool    // -v
	buildX bool    // -x
	buildO *string // -o
)

func addBuildFlags(cmd *command) {
	cmd.flag.BoolVar(&buildA, "a", false, "")
	cmd.flag.BoolVar(&buildI, "i", false, "")
	cmd.flag.Var((*stringsFlag)(&ctx.BuildTags), "tags", "")
}

func addBuildFlagsNVX(cmd *command) {
	cmd.flag.BoolVar(&buildN, "n", false, "")
	cmd.flag.BoolVar(&buildV, "v", false, "")
	cmd.flag.BoolVar(&buildX, "x", false, "")
}

// TODO(jbd): Build darwin/arm cross compiler during gomobile init.

func goIOSBuild(src string) error {
	// iOS builds are achievable only if the host machine is darwin.
	if runtime.GOOS != "darwin" {
		return nil
	}

	goroot := goEnv("GOROOT")
	gopath := goEnv("GOPATH")
	gocmd := exec.Command(
		`go`,
		`build`,
		`-tags=`+strconv.Quote(strings.Join(ctx.BuildTags, ",")))
	if buildV {
		gocmd.Args = append(gocmd.Args, "-v")
	}
	if buildI {
		gocmd.Args = append(gocmd.Args, "-i")
	}
	if buildX {
		gocmd.Args = append(gocmd.Args, "-x")
	}
	gocmd.Args = append(gocmd.Args, src)
	// TODO(jbd): Return a user-friendly error if xcode command line
	// tools are not available.
	gocmd.Stdout = os.Stdout
	gocmd.Stderr = os.Stderr
	gocmd.Env = []string{
		`GOOS=darwin`,
		`GOARCH=arm`, // TODO(jbd): Build for arm64
		`GOARM=7`,
		`CGO_ENABLED=1`,
		`CC=` + filepath.Join(goroot, "misc/ios/clangwrap.sh"), // TODO(jbd): reimplement clangwrap here.
		`CXX=` + filepath.Join(goroot, "misc/ios/clangwrap.sh"),
		`GOROOT=` + goroot,
		`GOPATH=` + gopath,
	}
	if buildX {
		printcmd("%s", strings.Join(gocmd.Env, " ")+" "+strings.Join(gocmd.Args, " "))
	}
	if !buildN {
		gocmd.Env = environ(gocmd.Env)
		if err := gocmd.Run(); err != nil {
			return err
		}
	}
	return nil
}

// goAndroidBuild builds a package.
// If libPath is specified then it builds as a shared library.
func goAndroidBuild(src, libPath string) error {
	version, err := goVersion()
	if err != nil {
		return err
	}

	gopath := goEnv("GOPATH")
	for _, p := range filepath.SplitList(gopath) {
		gomobilepath = filepath.Join(p, "pkg", "gomobile")
		if _, err = os.Stat(gomobilepath); err == nil {
			break
		}
	}
	if err != nil || gomobilepath == "" {
		return errors.New("android toolchain not installed, run:\n\tgomobile init")
	}
	verpath := filepath.Join(gomobilepath, "version")
	installedVersion, err := ioutil.ReadFile(verpath)
	if err != nil {
		return errors.New("android toolchain partially installed, run:\n\tgomobile init")
	}
	if !bytes.Equal(installedVersion, version) {
		return errors.New("android toolchain out of date, run:\n\tgomobile init")
	}

	ndkccpath = filepath.Join(gomobilepath, "android-"+ndkVersion)
	ndkccbin := filepath.Join(ndkccpath, "arm", "bin")
	if buildX {
		fmt.Fprintln(xout, "GOMOBILE="+gomobilepath)
	}

	gocmd := exec.Command(
		`go`,
		`build`,
		`-tags=`+strconv.Quote(strings.Join(ctx.BuildTags, ",")),
		`-toolexec=`+filepath.Join(ndkccbin, "toolexec"))
	if buildV {
		gocmd.Args = append(gocmd.Args, "-v")
	}
	if buildI {
		gocmd.Args = append(gocmd.Args, "-i")
	}
	if buildX {
		gocmd.Args = append(gocmd.Args, "-x")
	}
	if libPath == "" {
		if *buildO != "" {
			gocmd.Args = append(gocmd.Args, `-o`, *buildO)
		}
	} else {
		gocmd.Args = append(gocmd.Args,
			`-ldflags="-shared"`,
			`-o`, libPath,
		)
	}

	gocmd.Args = append(gocmd.Args, src)

	gocmd.Stdout = os.Stdout
	gocmd.Stderr = os.Stderr
	gocmd.Env = []string{
		`GOOS=android`,
		`GOARCH=arm`,
		`GOARM=7`,
		`CGO_ENABLED=1`,
		`CC=` + filepath.Join(ndkccbin, "arm-linux-androideabi-gcc"),
		`CXX=` + filepath.Join(ndkccbin, "arm-linux-androideabi-g++"),
		`GOGCCFLAGS="-fPIC -marm -pthread -fmessage-length=0"`,
		`GOROOT=` + goEnv("GOROOT"),
		`GOPATH=` + gopath,
		`GOMOBILEPATH=` + ndkccbin, // for toolexec
	}
	if buildX {
		printcmd("%s", strings.Join(gocmd.Env, " ")+" "+strings.Join(gocmd.Args, " "))
	}
	if !buildN {
		gocmd.Env = environ(gocmd.Env)
		if err := gocmd.Run(); err != nil {
			return err
		}
	}
	return nil
}

var importsAudioPkgs = make(map[string]struct{})

// pkgImportsAudio returns true if the given package or one of its
// dependencies imports the mobile/audio package.
func pkgImportsAudio(pkg *build.Package) bool {
	for _, path := range pkg.Imports {
		if path == "C" {
			continue
		}
		if _, ok := importsAudioPkgs[path]; ok {
			continue
		}
		importsAudioPkgs[path] = struct{}{}
		if strings.HasPrefix(path, "golang.org/x/mobile/audio") {
			return true
		}
		dPkg, err := ctx.Import(path, "", build.ImportComment)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error while looking up for the audio package: %v", err)
			os.Exit(2)
		}
		if pkgImportsAudio(dPkg) {
			return true
		}
	}
	return false
}

func init() {
	buildO = cmdBuild.flag.String("o", "", "output file")
	addBuildFlags(cmdBuild)
	addBuildFlagsNVX(cmdBuild)

	addBuildFlags(cmdInstall)
	addBuildFlagsNVX(cmdInstall)

	addBuildFlagsNVX(cmdInit)

	addBuildFlags(cmdBind)
	addBuildFlagsNVX(cmdBind)
}

// A random uninteresting private key.
// Must be consistent across builds so newer app versions can be installed.
const debugCert = `
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAy6ItnWZJ8DpX9R5FdWbS9Kr1U8Z7mKgqNByGU7No99JUnmyu
NQ6Uy6Nj0Gz3o3c0BXESECblOC13WdzjsH1Pi7/L9QV8jXOXX8cvkG5SJAyj6hcO
LOapjDiN89NXjXtyv206JWYvRtpexyVrmHJgRAw3fiFI+m4g4Qop1CxcIF/EgYh7
rYrqh4wbCM1OGaCleQWaOCXxZGm+J5YNKQcWpjZRrDrb35IZmlT0bK46CXUKvCqK
x7YXHgfhC8ZsXCtsScKJVHs7gEsNxz7A0XoibFw6DoxtjKzUCktnT0w3wxdY7OTj
9AR8mobFlM9W3yirX8TtwekWhDNTYEu8dwwykwIDAQABAoIBAA2hjpIhvcNR9H9Z
BmdEecydAQ0ZlT5zy1dvrWI++UDVmIp+Ve8BSd6T0mOqV61elmHi3sWsBN4M1Rdz
3N38lW2SajG9q0fAvBpSOBHgAKmfGv3Ziz5gNmtHgeEXfZ3f7J95zVGhlHqWtY95
JsmuplkHxFMyITN6WcMWrhQg4A3enKLhJLlaGLJf9PeBrvVxHR1/txrfENd2iJBH
FmxVGILL09fIIktJvoScbzVOneeWXj5vJGzWVhB17DHBbANGvVPdD5f+k/s5aooh
hWAy/yLKocr294C4J+gkO5h2zjjjSGcmVHfrhlXQoEPX+iW1TGoF8BMtl4Llc+jw
lKWKfpECgYEA9C428Z6CvAn+KJ2yhbAtuRo41kkOVoiQPtlPeRYs91Pq4+NBlfKO
2nWLkyavVrLx4YQeCeaEU2Xoieo9msfLZGTVxgRlztylOUR+zz2FzDBYGicuUD3s
EqC0Wv7tiX6dumpWyOcVVLmR9aKlOUzA9xemzIsWUwL3PpyONhKSq7kCgYEA1X2F
f2jKjoOVzglhtuX4/SP9GxS4gRf9rOQ1Q8DzZhyH2LZ6Dnb1uEQvGhiqJTU8CXxb
7odI0fgyNXq425Nlxc1Tu0G38TtJhwrx7HWHuFcbI/QpRtDYLWil8Zr7Q3BT9rdh
moo4m937hLMvqOG9pyIbyjOEPK2WBCtKW5yabqsCgYEAu9DkUBr1Qf+Jr+IEU9I8
iRkDSMeusJ6gHMd32pJVCfRRQvIlG1oTyTMKpafmzBAd/rFpjYHynFdRcutqcShm
aJUq3QG68U9EAvWNeIhA5tr0mUEz3WKTt4xGzYsyWES8u4tZr3QXMzD9dOuinJ1N
+4EEumXtSPKKDG3M8Qh+KnkCgYBUEVSTYmF5EynXc2xOCGsuy5AsrNEmzJqxDUBI
SN/P0uZPmTOhJIkIIZlmrlW5xye4GIde+1jajeC/nG7U0EsgRAV31J4pWQ5QJigz
0+g419wxIUFryGuIHhBSfpP472+w1G+T2mAGSLh1fdYDq7jx6oWE7xpghn5vb9id
EKLjdwKBgBtz9mzbzutIfAW0Y8F23T60nKvQ0gibE92rnUbjPnw8HjL3AZLU05N+
cSL5bhq0N5XHK77sscxW9vXjG0LJMXmFZPp9F6aV6ejkMIXyJ/Yz/EqeaJFwilTq
Mc6xR47qkdzu0dQ1aPm4XD7AWDtIvPo/GG2DKOucLBbQc2cOWtKS
-----END RSA PRIVATE KEY-----
`

// environ merges os.Environ and the given "key=value" pairs.
func environ(kv []string) []string {
	envs := map[string]string{}

	cur := os.Environ()
	new := make([]string, 0, len(cur)+len(kv))
	for _, ev := range cur {
		elem := strings.SplitN(ev, "=", 2)
		if len(elem) != 2 || elem[0] == "" {
			// pass the env var of unusual form untouched.
			// e.g. Windows may have env var names starting with "=".
			new = append(new, ev)
			continue
		}
		if goos == "windows" {
			elem[0] = strings.ToUpper(elem[0])
		}
		envs[elem[0]] = elem[1]
	}
	for _, ev := range kv {
		elem := strings.SplitN(ev, "=", 2)
		if len(elem) != 2 || elem[0] == "" {
			panic(fmt.Sprintf("malformed env var %q from input", ev))
		}
		if goos == "windows" {
			elem[0] = strings.ToUpper(elem[0])
		}
		envs[elem[0]] = elem[1]
	}
	for k, v := range envs {
		new = append(new, k+"="+v)
	}
	return new
}
