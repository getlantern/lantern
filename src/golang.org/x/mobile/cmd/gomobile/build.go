// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:generate go run gendex.go -o dex.go

package main

import (
	"bufio"
	"fmt"
	"go/build"
	"io"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"strconv"
	"strings"
)

var ctx = build.Default
var pkg *build.Package // TODO(crawshaw): remove global pkg variable
var tmpdir string

var cmdBuild = &command{
	run:   runBuild,
	Name:  "build",
	Usage: "[-target android|ios] [-o output] [build flags] [package]",
	Short: "compile android APK and iOS app",
	Long: `
Build compiles and encodes the app named by the import path.

The named package must define a main function.

The -target flag takes a target system name, either android (the
default) or ios.

For -target android, if an AndroidManifest.xml is defined in the
package directory, it is added to the APK output. Otherwise, a default
manifest is generated. By default, this builds a fat APK for all supported
instruction sets (arm, 386, amd64, arm64). A subset of instruction sets can
be selected by specifying target type with the architecture name. E.g.
-target=android/arm,android/386.

For -target ios, gomobile must be run on an OS X machine with Xcode
installed. Support is not complete.

If the package directory contains an assets subdirectory, its contents
are copied into the output.

The -o flag specifies the output file name. If not specified, the
output file name depends on the package built.

The -v flag provides verbose output, including the list of packages built.

The build flags -a, -i, -n, -x, -gcflags, -ldflags, -tags, and -work are
shared with the build command. For documentation, see 'go help build'.
`,
}

func runBuild(cmd *command) (err error) {
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

	ctx.GOARCH = targetArchs[0]
	ctx.GOOS = targetOS

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

	if pkg.Name != "main" && buildO != "" {
		return fmt.Errorf("cannot set -o when building non-main package")
	}

	var nmpkgs map[string]bool
	switch targetOS {
	case "android":
		if pkg.Name != "main" {
			for _, arch := range targetArchs {
				env := androidEnv[arch]
				if err := goBuild(pkg.ImportPath, env); err != nil {
					return err
				}
			}
			return nil
		}
		nmpkgs, err = goAndroidBuild(pkg, targetArchs)
		if err != nil {
			return err
		}
	case "darwin":
		// TODO: use targetArchs?
		if runtime.GOOS != "darwin" {
			return fmt.Errorf("-target=ios requires darwin host")
		}
		if pkg.Name != "main" {
			if err := goBuild(pkg.ImportPath, darwinArmEnv); err != nil {
				return err
			}
			return goBuild(pkg.ImportPath, darwinArm64Env)
		}
		nmpkgs, err = goIOSBuild(pkg)
		if err != nil {
			return err
		}
	}

	if !nmpkgs["golang.org/x/mobile/app"] {
		return fmt.Errorf(`%s does not import "golang.org/x/mobile/app"`, pkg.ImportPath)
	}

	return nil
}

var nmRE = regexp.MustCompile(`[0-9a-f]{8} t (golang.org/x.*/[^.]*)`)

func extractPkgs(nm string, path string) (map[string]bool, error) {
	if buildN {
		return map[string]bool{"golang.org/x/mobile/app": true}, nil
	}
	r, w := io.Pipe()
	cmd := exec.Command(nm, path)
	cmd.Stdout = w
	cmd.Stderr = os.Stderr

	nmpkgs := make(map[string]bool)
	errc := make(chan error, 1)
	go func() {
		s := bufio.NewScanner(r)
		for s.Scan() {
			if res := nmRE.FindStringSubmatch(s.Text()); res != nil {
				nmpkgs[res[1]] = true
			}
		}
		errc <- s.Err()
	}()

	err := cmd.Run()
	w.Close()
	if err != nil {
		return nil, fmt.Errorf("%s %s: %v", nm, path, err)
	}
	if err := <-errc; err != nil {
		return nil, fmt.Errorf("%s %s: %v", nm, path, err)
	}
	return nmpkgs, nil
}

func importsApp(pkg *build.Package) error {
	// Building a program, make sure it is appropriate for mobile.
	for _, path := range pkg.Imports {
		if path == "golang.org/x/mobile/app" {
			return nil
		}
	}
	return fmt.Errorf(`%s does not import "golang.org/x/mobile/app"`, pkg.ImportPath)
}

var xout io.Writer = os.Stderr

func printcmd(format string, args ...interface{}) {
	cmd := fmt.Sprintf(format+"\n", args...)
	if tmpdir != "" {
		cmd = strings.Replace(cmd, tmpdir, "$WORK", -1)
	}
	if androidHome := os.Getenv("ANDROID_HOME"); androidHome != "" {
		cmd = strings.Replace(cmd, androidHome, "$ANDROID_HOME", -1)
	}
	if gomobilepath != "" {
		cmd = strings.Replace(cmd, gomobilepath, "$GOMOBILE", -1)
	}
	if goroot := goEnv("GOROOT"); goroot != "" {
		cmd = strings.Replace(cmd, goroot, "$GOROOT", -1)
	}
	if gopath := goEnv("GOPATH"); gopath != "" {
		cmd = strings.Replace(cmd, gopath, "$GOPATH", -1)
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
	buildA       bool   // -a
	buildI       bool   // -i
	buildN       bool   // -n
	buildV       bool   // -v
	buildX       bool   // -x
	buildO       string // -o
	buildGcflags string // -gcflags
	buildLdflags string // -ldflags
	buildTarget  string // -target
	buildWork    bool   // -work
)

func addBuildFlags(cmd *command) {
	cmd.flag.StringVar(&buildO, "o", "", "")
	cmd.flag.StringVar(&buildGcflags, "gcflags", "", "")
	cmd.flag.StringVar(&buildLdflags, "ldflags", "", "")
	cmd.flag.StringVar(&buildTarget, "target", "android", "")

	cmd.flag.BoolVar(&buildA, "a", false, "")
	cmd.flag.BoolVar(&buildI, "i", false, "")
	cmd.flag.Var((*stringsFlag)(&ctx.BuildTags), "tags", "")
}

func addBuildFlagsNVXWork(cmd *command) {
	cmd.flag.BoolVar(&buildN, "n", false, "")
	cmd.flag.BoolVar(&buildV, "v", false, "")
	cmd.flag.BoolVar(&buildX, "x", false, "")
	cmd.flag.BoolVar(&buildWork, "work", false, "")
}

type binInfo struct {
	hasPkgApp bool
	hasPkgAL  bool
}

func init() {
	addBuildFlags(cmdBuild)
	addBuildFlagsNVXWork(cmdBuild)

	addBuildFlags(cmdInstall)
	addBuildFlagsNVXWork(cmdInstall)

	addBuildFlagsNVXWork(cmdInit)

	addBuildFlags(cmdBind)
	addBuildFlagsNVXWork(cmdBind)
}

func goBuild(src string, env []string, args ...string) error {
	return goCmd("build", []string{src}, env, args...)
}

func goInstall(srcs []string, env []string, args ...string) error {
	return goCmd("install", srcs, env, args...)
}

func goCmd(subcmd string, srcs []string, env []string, args ...string) error {
	// The -p flag is to speed up darwin/arm builds.
	// Remove when golang.org/issue/10477 is resolved.
	cmd := exec.Command(
		"go",
		subcmd,
		fmt.Sprintf("-p=%d", runtime.NumCPU()),
		"-pkgdir="+pkgdir(env),
		"-tags="+strconv.Quote(strings.Join(ctx.BuildTags, ",")),
	)
	if buildV {
		cmd.Args = append(cmd.Args, "-v")
	}
	if subcmd != "install" && buildI {
		cmd.Args = append(cmd.Args, "-i")
	}
	if buildX {
		cmd.Args = append(cmd.Args, "-x")
	}
	if buildGcflags != "" {
		cmd.Args = append(cmd.Args, "-gcflags", buildGcflags)
	}
	if buildLdflags != "" {
		cmd.Args = append(cmd.Args, "-ldflags", buildLdflags)
	}
	if buildWork {
		cmd.Args = append(cmd.Args, "-work")
	}
	cmd.Args = append(cmd.Args, args...)
	cmd.Args = append(cmd.Args, srcs...)
	cmd.Env = append([]string{}, env...)
	return runCmd(cmd)
}

func parseBuildTarget(buildTarget string) (os string, archs []string, _ error) {
	if buildTarget == "" {
		return "", nil, fmt.Errorf(`invalid target ""`)
	}

	all := false
	archNames := []string{}
	for i, p := range strings.Split(buildTarget, ",") {
		osarch := strings.SplitN(p, "/", 2) // len(osarch) > 0
		if osarch[0] != "android" && osarch[0] != "ios" {
			return "", nil, fmt.Errorf(`unsupported os`)
		}

		if i == 0 {
			os = osarch[0]
		}

		if os != osarch[0] {
			return "", nil, fmt.Errorf(`cannot target different OSes`)
		}

		if len(osarch) == 1 {
			all = true
		} else {
			archNames = append(archNames, osarch[1])
		}
	}

	// verify all archs are supported one while deduping.
	var supported []string
	switch os {
	case "ios":
		supported = []string{"arm", "arm64", "amd64"}
	case "android":
		for arch, tc := range ndk {
			if tc.minGoVer <= goVersion {
				supported = append(supported, arch)
			}
		}
	}

	isSupported := func(arch string) bool {
		for _, a := range supported {
			if a == arch {
				return true
			}
		}
		return false
	}

	seen := map[string]bool{}
	for _, arch := range archNames {
		if _, ok := seen[arch]; ok {
			continue
		}
		if !isSupported(arch) {
			return "", nil, fmt.Errorf(`unsupported arch: %q`, arch)
		}

		seen[arch] = true
		archs = append(archs, arch)
	}

	targetOS := os
	if os == "ios" {
		targetOS = "darwin"
	}
	if all {
		return targetOS, supported, nil
	}
	return targetOS, archs, nil
}
