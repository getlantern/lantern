// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// useStrippedNDK determines whether the init subcommand fetches the GCC
// toolchain from the original Android NDK, or from the stripped-down NDK
// hosted specifically for the gomobile tool.
//
// There is a significant size different (400MB compared to 30MB).
var useStrippedNDK = true

const ndkVersion = "ndk-r11c"
const openALVersion = "openal-soft-1.16.0.1"

var (
	goos    = runtime.GOOS
	goarch  = runtime.GOARCH
	ndkarch string
)

func init() {
	switch runtime.GOARCH {
	case "amd64":
		ndkarch = "x86_64"
	case "386":
		ndkarch = "x86"
	default:
		ndkarch = runtime.GOARCH
	}
}

var cmdInit = &command{
	run:   runInit,
	Name:  "init",
	Usage: "[-u]",
	Short: "install android compiler toolchain",
	Long: `
Init installs the Android C++ compiler toolchain and builds copies
of the Go standard library for mobile devices.

When first run, it downloads part of the Android NDK.
The toolchain is installed in $GOPATH/pkg/gomobile.

The -u option forces download and installation of the new toolchain
even when the toolchain exists.
`,
}

var initU bool // -u

func init() {
	cmdInit.flag.BoolVar(&initU, "u", false, "force toolchain download")
}

func runInit(cmd *command) error {
	gopaths := filepath.SplitList(goEnv("GOPATH"))
	if len(gopaths) == 0 {
		return fmt.Errorf("GOPATH is not set")
	}
	gomobilepath = filepath.Join(gopaths[0], "pkg/gomobile")

	verpath := filepath.Join(gomobilepath, "version")
	if buildX || buildN {
		fmt.Fprintln(xout, "GOMOBILE="+gomobilepath)
	}
	removeGomobilepkg()

	if err := mkdir(ndk.Root()); err != nil {
		return err
	}

	if buildN {
		tmpdir = filepath.Join(gomobilepath, "work")
	} else {
		var err error
		tmpdir, err = ioutil.TempDir(gomobilepath, "work-")
		if err != nil {
			return err
		}
	}
	if buildX || buildN {
		fmt.Fprintln(xout, "WORK="+tmpdir)
	}
	defer func() {
		if buildWork {
			fmt.Printf("WORK=%s\n", tmpdir)
			return
		}
		removeAll(tmpdir)
	}()

	if err := envInit(); err != nil {
		return err
	}

	if err := fetchNDK(); err != nil {
		return err
	}
	if err := fetchOpenAL(); err != nil {
		return err
	}

	if runtime.GOOS == "darwin" {
		// Install common x/mobile packages for local development.
		// These are often slow to compile (due to cgo) and easy to forget.
		//
		// Limited to darwin for now as it is common for linux to
		// not have GLES installed.
		//
		// TODO: consider testing GLES installation and suggesting it here
		for _, pkg := range commonPkgs {
			if err := installPkg(pkg, nil); err != nil {
				return err
			}
		}
	}

	// Install standard libraries for cross compilers.
	start := time.Now()
	var androidArgs []string
	if goVersion == go1_6 {
		// Ideally this would be -buildmode=c-shared.
		// https://golang.org/issue/13234.
		androidArgs = []string{"-gcflags=-shared", "-ldflags=-shared"}
	}
	for _, env := range androidEnv {
		if err := installStd(env, androidArgs...); err != nil {
			return err
		}
	}

	if err := installDarwin(); err != nil {
		return err
	}

	if buildX || buildN {
		printcmd("go version > %s", verpath)
	}
	if !buildN {
		if err := ioutil.WriteFile(verpath, goVersionOut, 0644); err != nil {
			return err
		}
	}
	if buildV {
		took := time.Since(start) / time.Second * time.Second
		fmt.Fprintf(os.Stderr, "\nDone, build took %s.\n", took)
	}
	return nil
}

var commonPkgs = []string{
	"golang.org/x/mobile/gl",
	"golang.org/x/mobile/app",
	"golang.org/x/mobile/exp/app/debug",
}

func installDarwin() error {
	if goos != "darwin" {
		return nil // Only build iOS compilers on OS X.
	}
	if err := installStd(darwinArmEnv); err != nil {
		return err
	}
	if err := installStd(darwinArm64Env); err != nil {
		return err
	}
	// TODO(crawshaw): darwin/386 for the iOS simulator?
	if err := installStd(darwinAmd64Env, "-tags=ios"); err != nil {
		return err
	}
	return nil
}

func installStd(env []string, args ...string) error {
	return installPkg("std", env, args...)
}

func installPkg(pkg string, env []string, args ...string) error {
	tOS, tArch, pd := getenv(env, "GOOS"), getenv(env, "GOARCH"), pkgdir(env)
	if tOS != "" && tArch != "" {
		if buildV {
			fmt.Fprintf(os.Stderr, "\n# Installing %s for %s/%s.\n", pkg, tOS, tArch)
		}
		args = append(args, "-pkgdir="+pd)
	} else {
		if buildV {
			fmt.Fprintf(os.Stderr, "\n# Installing %s.\n", pkg)
		}
	}

	// The -p flag is to speed up darwin/arm builds.
	// Remove when golang.org/issue/10477 is resolved.
	cmd := exec.Command("go", "install", fmt.Sprintf("-p=%d", runtime.NumCPU()))
	cmd.Args = append(cmd.Args, args...)
	if buildV {
		cmd.Args = append(cmd.Args, "-v")
	}
	if buildX {
		cmd.Args = append(cmd.Args, "-x")
	}
	if buildWork {
		cmd.Args = append(cmd.Args, "-work")
	}
	cmd.Args = append(cmd.Args, pkg)
	cmd.Env = append([]string{}, env...)
	return runCmd(cmd)
}

func removeGomobilepkg() {
	dir, err := os.Open(gomobilepath)
	if err != nil {
		return
	}
	names, err := dir.Readdirnames(-1)
	if err != nil {
		return
	}
	for _, name := range names {
		if name == "dl" {
			continue
		}
		removeAll(filepath.Join(gomobilepath, name))
	}
}

func move(dst, src string, names ...string) error {
	for _, name := range names {
		srcf := filepath.Join(src, name)
		dstf := filepath.Join(dst, name)
		if buildX || buildN {
			printcmd("mv %s %s", srcf, dstf)
		}
		if buildN {
			continue
		}
		if goos == "windows" {
			// os.Rename fails if dstf already exists.
			removeAll(dstf)
		}
		if err := os.Rename(srcf, dstf); err != nil {
			return err
		}
	}
	return nil
}

func mkdir(dir string) error {
	if buildX || buildN {
		printcmd("mkdir -p %s", dir)
	}
	if buildN {
		return nil
	}
	return os.MkdirAll(dir, 0755)
}

func symlink(src, dst string) error {
	if buildX || buildN {
		printcmd("ln -s %s %s", src, dst)
	}
	if buildN {
		return nil
	}
	if goos == "windows" {
		return doCopyAll(dst, src)
	}
	return os.Symlink(src, dst)
}

func rm(name string) error {
	if buildX || buildN {
		printcmd("rm %s", name)
	}
	if buildN {
		return nil
	}
	return os.Remove(name)
}

func fetchOpenAL() error {
	url := "https://dl.google.com/go/mobile/gomobile-" + openALVersion + ".tar.gz"
	archive, err := fetch(url)
	if err != nil {
		return err
	}
	if err := extract("openal", archive); err != nil {
		return err
	}
	if goos == "windows" {
		resetReadOnlyFlagAll(filepath.Join(tmpdir, "openal"))
	}
	ndkroot := ndk.Root()
	src := filepath.Join(tmpdir, "openal/include/AL")
	for arch := range androidEnv {
		toolchain := ndk.Toolchain(arch)
		dst := filepath.Join(ndkroot, toolchain.arch+"/sysroot/usr/include/AL")
		if buildX || buildN {
			printcmd("cp -r %s %s", src, dst)
		}
		if buildN {
			continue
		}
		if err := doCopyAll(dst, src); err != nil {
			return err
		}
	}
	libDst := filepath.Join(ndkroot, "openal")
	libSrc := filepath.Join(tmpdir, "openal")
	if err := mkdir(libDst); err != nil {
		return nil
	}
	if err := move(libDst, libSrc, "lib"); err != nil {
		return err
	}
	return nil
}

func extract(dst, src string) error {
	if buildX || buildN {
		printcmd("tar xfz %s", src)
	}
	if buildN {
		return nil
	}
	tf, err := os.Open(src)
	if err != nil {
		return err
	}
	defer tf.Close()
	zr, err := gzip.NewReader(tf)
	if err != nil {
		return err
	}
	tr := tar.NewReader(zr)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		dst := filepath.Join(tmpdir, dst+"/"+hdr.Name)
		if hdr.Typeflag == tar.TypeSymlink {
			if err := symlink(hdr.Linkname, dst); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
			return err
		}
		f, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, os.FileMode(hdr.Mode)&0777)
		if err != nil {
			return err
		}
		if _, err := io.Copy(f, tr); err != nil {
			return err
		}
		if err := f.Close(); err != nil {
			return err
		}
	}
	return nil
}

func fetchNDK() error {
	if useStrippedNDK {
		if err := fetchStrippedNDK(); err != nil {
			return err
		}
	} else {
		if err := fetchFullNDK(); err != nil {
			return err
		}
	}
	if goos == "windows" {
		resetReadOnlyFlagAll(filepath.Join(tmpdir, "android-"+ndkVersion))
	}

	for arch := range androidEnv {
		toolchain := ndk.Toolchain(arch)
		dst := filepath.Join(ndk.Root(), toolchain.arch)
		dstSysroot := filepath.Join(dst, "sysroot")
		if err := mkdir(dstSysroot); err != nil {
			return err
		}

		srcSysroot := filepath.Join(tmpdir, fmt.Sprintf(
			"android-%s/platforms/%s/arch-%s", ndkVersion, toolchain.platform, toolchain.arch))
		if err := move(dstSysroot, srcSysroot, "usr"); err != nil {
			return err
		}

		ndkpath := filepath.Join(tmpdir, fmt.Sprintf(
			"android-%s/toolchains/%s/prebuilt", ndkVersion, toolchain.gcc))
		if goos == "windows" && ndkarch == "x86" {
			ndkpath = filepath.Join(ndkpath, "windows")
		} else {
			ndkpath = filepath.Join(ndkpath, goos+"-"+ndkarch)
		}
		if err := move(dst, ndkpath, "bin", "lib", "libexec"); err != nil {
			return err
		}

		// ndk-r10e arm64 toolchain has a bug in ld.bfd and for aarch64
		// ld.bfd is the default linker. Workaround by switching the
		// default to ld.gold.
		// TODO(hyangah): remove this when using the new version of ndk.
		if toolchain.arch == "arm64" {
			ld := filepath.Join(dst, "bin/aarch64-linux-android-ld")
			ldgold := ld + ".gold"
			if goos == "windows" {
				ld += ".exe"
				ldgold += ".exe"
			}
			if err := rm(ld); err != nil {
				return err
			}
			if err := symlink(ldgold, ld); err != nil {
				return err
			}
		}

		linkpath := filepath.Join(dst, toolchain.toolPrefix+"/bin")
		if err := mkdir(linkpath); err != nil {
			return err
		}

		for _, name := range []string{"ld", "as", "gcc", "g++"} {
			if goos == "windows" {
				name += ".exe"
			}
			if err := symlink(filepath.Join(dst, "bin", toolchain.toolPrefix+"-"+name), filepath.Join(linkpath, name)); err != nil {
				return err
			}
		}
	}
	return nil
}

func fetchStrippedNDK() error {
	url := "https://dl.google.com/go/mobile/gomobile-" + ndkVersion + "-" + goos + "-" + ndkarch + ".tar.gz"
	archive, err := fetch(url)
	if err != nil {
		return err
	}
	return extract("", archive)
}

func fetchFullNDK() error {
	url := "https://dl.google.com/android/ndk/android-" + ndkVersion + "-" + goos + "-" + ndkarch + "."
	if goos == "windows" {
		url += "exe"
	} else {
		url += "bin"
	}
	archive, err := fetch(url)
	if err != nil {
		return err
	}

	// The self-extracting ndk dist file for Windows terminates
	// with an error (error code 2 - corrupted or incomplete file)
	// but there are no details on what caused this.
	//
	// Strangely, if the file is launched from file browser or
	// unzipped with 7z.exe no error is reported.
	//
	// In general we use the stripped NDK, so this code path
	// is not used, and 7z.exe is not a normal dependency.
	var inflate *exec.Cmd
	if goos != "windows" {
		// The downloaded archive is executed on linux and os x to unarchive.
		// To do this execute permissions are needed.
		os.Chmod(archive, 0755)

		inflate = exec.Command(archive)
	} else {
		inflate = exec.Command("7z.exe", "x", archive)
	}
	inflate.Dir = tmpdir
	return runCmd(inflate)
}

// fetch reads a URL into $GOPATH/pkg/gomobile/dl and returns the path
// to the downloaded file. Downloading is skipped if the file is
// already present.
func fetch(url string) (dst string, err error) {
	if err := mkdir(filepath.Join(gomobilepath, "dl")); err != nil {
		return "", err
	}
	name := path.Base(url)
	dst = filepath.Join(gomobilepath, "dl", name)

	// Use what's in the cache if force update is not required.
	if !initU {
		if buildX {
			printcmd("stat %s", dst)
		}
		if _, err = os.Stat(dst); err == nil {
			return dst, nil
		}
	}
	if buildX {
		printcmd("curl -o%s %s", dst, url)
	}
	if buildN {
		return dst, nil
	}

	if buildV {
		fmt.Fprintf(os.Stderr, "Downloading %s.\n", url)
	}

	f, err := ioutil.TempFile(tmpdir, "partial-"+name)
	if err != nil {
		return "", err
	}
	defer func() {
		if err != nil {
			f.Close()
			os.Remove(f.Name())
		}
	}()
	hashw := sha256.New()

	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		err = fmt.Errorf("error fetching %v, status: %v", url, resp.Status)
	} else {
		_, err = io.Copy(io.MultiWriter(hashw, f), resp.Body)
	}
	if err2 := resp.Body.Close(); err == nil {
		err = err2
	}
	if err != nil {
		return "", err
	}
	if err = f.Close(); err != nil {
		return "", err
	}
	hash := hex.EncodeToString(hashw.Sum(nil))
	if fetchHashes[name] != hash {
		return "", fmt.Errorf("sha256 for %q: %v, want %v", name, hash, fetchHashes[name])
	}
	if err = os.Rename(f.Name(), dst); err != nil {
		return "", err
	}
	return dst, nil
}

func doCopyAll(dst, src string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, errin error) (err error) {
		if errin != nil {
			return errin
		}
		prefixLen := len(src)
		if len(path) > prefixLen {
			prefixLen++ // file separator
		}
		outpath := filepath.Join(dst, path[prefixLen:])
		if info.IsDir() {
			return os.Mkdir(outpath, 0755)
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.OpenFile(outpath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, info.Mode())
		if err != nil {
			return err
		}
		defer func() {
			if errc := out.Close(); err == nil {
				err = errc
			}
		}()
		_, err = io.Copy(out, in)
		return err
	})
}

func removeAll(path string) error {
	if buildX || buildN {
		printcmd(`rm -r -f "%s"`, path)
	}
	if buildN {
		return nil
	}

	// os.RemoveAll behaves differently in windows.
	// http://golang.org/issues/9606
	if goos == "windows" {
		resetReadOnlyFlagAll(path)
	}

	return os.RemoveAll(path)
}

func resetReadOnlyFlagAll(path string) error {
	fi, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !fi.IsDir() {
		return os.Chmod(path, 0666)
	}
	fd, err := os.Open(path)
	if err != nil {
		return err
	}
	defer fd.Close()

	names, _ := fd.Readdirnames(-1)
	for _, name := range names {
		resetReadOnlyFlagAll(path + string(filepath.Separator) + name)
	}
	return nil
}

func goEnv(name string) string {
	if val := os.Getenv(name); val != "" {
		return val
	}
	val, err := exec.Command("go", "env", name).Output()
	if err != nil {
		panic(err) // the Go tool was tested to work earlier
	}
	return strings.TrimSpace(string(val))
}

func runCmd(cmd *exec.Cmd) error {
	if buildX || buildN {
		dir := ""
		if cmd.Dir != "" {
			dir = "PWD=" + cmd.Dir + " "
		}
		env := strings.Join(cmd.Env, " ")
		if env != "" {
			env += " "
		}
		printcmd("%s%s%s", dir, env, strings.Join(cmd.Args, " "))
	}

	buf := new(bytes.Buffer)
	buf.WriteByte('\n')
	if buildV {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	} else {
		cmd.Stdout = buf
		cmd.Stderr = buf
	}

	if buildWork {
		if goos == "windows" {
			cmd.Env = append(cmd.Env, `TEMP=`+tmpdir)
			cmd.Env = append(cmd.Env, `TMP=`+tmpdir)
		} else {
			cmd.Env = append(cmd.Env, `TMPDIR=`+tmpdir)
		}
	}

	if !buildN {
		cmd.Env = environ(cmd.Env)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("%s failed: %v%s", strings.Join(cmd.Args, " "), err, buf)
		}
	}
	return nil
}
