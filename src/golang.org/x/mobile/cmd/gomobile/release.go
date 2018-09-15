// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//+build ignore

// Release is a tool for building the NDK tarballs hosted on dl.google.com.
//
// The Go toolchain only needs the gcc compiler and headers, which are ~10MB.
// The entire NDK is ~400MB. Building smaller toolchain binaries reduces the
// run time of gomobile init significantly.
package main

import (
	"archive/tar"
	"bufio"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"hash"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

const ndkVersion = "ndk-r11c"

type version struct {
	os   string
	arch string
}

var hosts = []version{
	{"darwin", "x86_64"},
	{"linux", "x86_64"},
	{"windows", "x86"},
	{"windows", "x86_64"},
}

type target struct {
	arch       string
	platform   string
	gcc        string
	toolPrefix string
}

var targets = []target{
	{"arm", "android-15", "arm-linux-androideabi-4.9", "arm-linux-androideabi"},
	{"arm64", "android-21", "aarch64-linux-android-4.9", "aarch64-linux-android"},
	{"x86", "android-15", "x86-4.9", "i686-linux-android"},
	{"x86_64", "android-21", "x86_64-4.9", "x86_64-linux-android"},
}

var (
	ndkdir = flag.String("ndkdir", "", "Directory for the downloaded NDKs for caching")
	tmpdir string
)

func main() {
	flag.Parse()
	var err error
	tmpdir, err = ioutil.TempDir("", "gomobile-release-")
	if err != nil {
		log.Panic(err)
	}
	defer os.RemoveAll(tmpdir)

	fmt.Println("var fetchHashes = map[string]string{")
	for _, host := range hosts {
		if err := mkpkg(host); err != nil {
			log.Panic(err)
		}
	}
	if err := mkALPkg(); err != nil {
		log.Panic(err)
	}

	fmt.Println("}")
}

func run(dir, path string, args ...string) error {
	cmd := exec.Command(path, args...)
	cmd.Dir = dir
	buf, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Printf("%s\n", buf)
	}
	return err
}

func mkALPkg() (err error) {
	ndkPath, _, err := fetchNDK(version{os: hostOS, arch: hostArch})
	if err != nil {
		return err
	}
	ndkRoot := tmpdir + "/android-" + ndkVersion
	if err := inflate(tmpdir, ndkPath); err != nil {
		return err
	}

	alTmpDir, err := ioutil.TempDir("", "openal-release-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(alTmpDir)

	if err := run(alTmpDir, "git", "clone", "-v", "git://repo.or.cz/openal-soft.git", alTmpDir); err != nil {
		return err
	}
	// TODO: use more recent revision?
	if err := run(alTmpDir, "git", "checkout", "19f79be57b8e768f44710b6d26017bc1f8c8fbda"); err != nil {
		return err
	}

	files := map[string]string{
		"include/AL/al.h":  "include/AL/al.h",
		"include/AL/alc.h": "include/AL/alc.h",
		"COPYING":          "include/AL/COPYING",
	}

	for _, t := range targets {
		abi := t.arch
		if abi == "arm" {
			abi = "armeabi"
		}
		buildDir := alTmpDir + "/build/" + abi
		toolchain := buildDir + "/toolchain"
		if err := os.MkdirAll(toolchain, 0755); err != nil {
			return err
		}
		// standalone ndk toolchains make openal-soft's build config easier.
		if err := run(ndkRoot, "env",
			"build/tools/make-standalone-toolchain.sh",
			"--arch="+t.arch,
			"--platform="+t.platform,
			"--install-dir="+toolchain); err != nil {
			return fmt.Errorf("make-standalone-toolchain.sh failed: %v", err)
		}

		orgPath := os.Getenv("PATH")
		os.Setenv("PATH", toolchain+"/bin"+string(os.PathListSeparator)+orgPath)
		if err := run(buildDir, "cmake",
			"../../",
			"-DCMAKE_TOOLCHAIN_FILE=../../XCompile-Android.txt",
			"-DHOST="+t.toolPrefix); err != nil {
			return fmt.Errorf("cmake failed: %v", err)
		}
		os.Setenv("PATH", orgPath)

		if err := run(buildDir, "make"); err != nil {
			return fmt.Errorf("make failed: %v", err)
		}

		files["build/"+abi+"/libopenal.so"] = "lib/" + abi + "/libopenal.so"
	}

	// Build the tarball.
	aw := newArchiveWriter("gomobile-openal-soft-1.16.0.1.tar.gz")
	defer func() {
		err2 := aw.Close()
		if err == nil {
			err = err2
		}
	}()

	for src, dst := range files {
		f, err := os.Open(filepath.Join(alTmpDir, src))
		if err != nil {
			return err
		}
		fi, err := f.Stat()
		if err != nil {
			return err
		}
		aw.WriteHeader(&tar.Header{
			Name: dst,
			Mode: int64(fi.Mode()),
			Size: fi.Size(),
		})
		io.Copy(aw, f)
		f.Close()
	}
	return nil
}

func fetchNDK(host version) (binPath, url string, err error) {
	ndkName := "android-" + ndkVersion + "-" + host.os + "-" + host.arch + ".zip"

	url = "https://dl.google.com/android/repository/" + ndkName
	binPath = *ndkdir
	if binPath == "" {
		binPath = tmpdir
	}
	binPath += "/" + ndkName

	if _, err := os.Stat(binPath); err == nil {
		log.Printf("\t%q: using cached NDK\n", ndkName)
		return binPath, url, nil
	}

	log.Printf("%s\n", url)
	binHash, err := fetch(binPath, url)
	if err != nil {
		return "", "", err
	}

	fmt.Printf("\t%q: %q,\n", ndkName, binHash)
	return binPath, url, nil
}

func mkpkg(host version) error {
	binPath, url, err := fetchNDK(host)
	if err != nil {
		return err
	}

	src := tmpdir + "/" + host.os + "-" + host.arch + "-src"
	dst := tmpdir + "/" + host.os + "-" + host.arch + "-dst"
	defer os.RemoveAll(src)
	defer os.RemoveAll(dst)

	if err := os.Mkdir(src, 0755); err != nil {
		return err
	}

	if err := inflate(src, binPath); err != nil {
		return err
	}

	// The NDK is unpacked into tmpdir/linux-x86_64-src/android-{{ndkVersion}}.
	// Move the files we want into tmpdir/linux-x86_64-dst/android-{{ndkVersion}}.
	// We preserve the same file layout to make the full NDK interchangable
	// with the cut down file.
	for _, t := range targets {
		usr := fmt.Sprintf("android-%s/platforms/%s/arch-%s/usr/", ndkVersion, t.platform, t.arch)
		gcc := fmt.Sprintf("android-%s/toolchains/%s/prebuilt/", ndkVersion, t.gcc)

		if host.os == "windows" && host.arch == "x86" {
			gcc += "windows"
		} else {
			gcc += host.os + "-" + host.arch
		}

		if err := os.MkdirAll(dst+"/"+usr, 0755); err != nil {
			return err
		}
		if err := os.MkdirAll(dst+"/"+gcc, 0755); err != nil {
			return err
		}

		subdirs := []string{"include", "lib"}
		switch t.arch {
		case "x86_64":
			subdirs = append(subdirs, "lib64", "libx32")
		}
		if err := move(dst+"/"+usr, src+"/"+usr, subdirs...); err != nil {
			return err
		}

		if err := move(dst+"/"+gcc, src+"/"+gcc, "bin", "lib", "libexec", "COPYING", "COPYING.LIB"); err != nil {
			return err
		}
	}

	// Build the tarball.
	aw := newArchiveWriter("gomobile-" + ndkVersion + "-" + host.os + "-" + host.arch + ".tar.gz")
	defer func() {
		err2 := aw.Close()
		if err == nil {
			err = err2
		}
	}()

	readme := "Stripped down copy of:\n\n\t" + url + "\n\nGenerated by golang.org/x/mobile/cmd/gomobile/release.go."
	aw.WriteHeader(&tar.Header{
		Name: "README",
		Mode: 0644,
		Size: int64(len(readme)),
	})
	io.WriteString(aw, readme)

	return filepath.Walk(dst, func(path string, fi os.FileInfo, err error) error {
		defer func() {
			if err != nil {
				err = fmt.Errorf("%s: %v", path, err)
			}
		}()
		if err != nil {
			return err
		}
		if path == dst {
			return nil
		}
		name := path[len(dst)+1:]
		if fi.IsDir() {
			return nil
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			dst, err := os.Readlink(path)
			if err != nil {
				log.Printf("bad symlink: %s", name)
				return nil
			}
			aw.WriteHeader(&tar.Header{
				Name:     name,
				Linkname: dst,
				Typeflag: tar.TypeSymlink,
			})
			return nil
		}
		aw.WriteHeader(&tar.Header{
			Name: name,
			Mode: int64(fi.Mode()),
			Size: fi.Size(),
		})
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		io.Copy(aw, f)
		f.Close()
		return nil
	})
}

func fetch(dst, url string) (string, error) {
	f, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0755)
	if err != nil {
		return "", err
	}
	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	if sc := resp.StatusCode; sc != http.StatusOK {
		return "", fmt.Errorf("invalid HTTP status %d", sc)
	}
	hashw := sha256.New()
	_, err = io.Copy(io.MultiWriter(hashw, f), resp.Body)
	err2 := resp.Body.Close()
	err3 := f.Close()
	if err != nil {
		return "", err
	}
	if err2 != nil {
		return "", err2
	}
	if err3 != nil {
		return "", err3
	}
	return hex.EncodeToString(hashw.Sum(nil)), nil
}

func inflate(dst, path string) error {
	unzip := "unzip"
	cmd := exec.Command(unzip, path)
	cmd.Dir = dst
	out, err := cmd.CombinedOutput()
	if err != nil {
		os.Stderr.Write(out)
		return err
	}
	return nil
}

func move(dst, src string, names ...string) error {
	for _, name := range names {
		if err := os.Rename(src+"/"+name, dst+"/"+name); err != nil {
			return err
		}
	}
	return nil
}

// archiveWriter writes a .tar.gz archive and prints its SHA256 to stdout.
// If any error occurs, it continues as a no-op until Close, when it is reported.
type archiveWriter struct {
	name  string
	hashw hash.Hash
	f     *os.File
	zw    *gzip.Writer
	bw    *bufio.Writer
	tw    *tar.Writer
	err   error
}

func (aw *archiveWriter) WriteHeader(h *tar.Header) {
	if aw.err != nil {
		return
	}
	aw.err = aw.tw.WriteHeader(h)
}

func (aw *archiveWriter) Write(b []byte) (n int, err error) {
	if aw.err != nil {
		return len(b), nil
	}
	n, aw.err = aw.tw.Write(b)
	return n, nil
}

func (aw *archiveWriter) Close() (err error) {
	err = aw.tw.Close()
	if aw.err == nil {
		aw.err = err
	}
	err = aw.zw.Close()
	if aw.err == nil {
		aw.err = err
	}
	err = aw.bw.Flush()
	if aw.err == nil {
		aw.err = err
	}
	err = aw.f.Close()
	if aw.err == nil {
		aw.err = err
	}
	if aw.err != nil {
		return aw.err
	}
	hash := hex.EncodeToString(aw.hashw.Sum(nil))
	fmt.Printf("\t%q: %q,\n", aw.name, hash)
	return nil
}

func newArchiveWriter(name string) *archiveWriter {
	aw := &archiveWriter{name: name}
	aw.f, aw.err = os.Create(name)
	if aw.err != nil {
		return aw
	}
	aw.hashw = sha256.New()
	aw.bw = bufio.NewWriter(io.MultiWriter(aw.f, aw.hashw))
	aw.zw, aw.err = gzip.NewWriterLevel(aw.bw, gzip.BestCompression)
	if aw.err != nil {
		return aw
	}
	aw.tw = tar.NewWriter(aw.zw)
	return aw
}

var hostOS, hostArch string

func init() {
	switch runtime.GOOS {
	case "linux", "darwin":
		hostOS = runtime.GOOS
	}
	switch runtime.GOARCH {
	case "386":
		hostArch = "x86"
	case "amd64":
		hostArch = "x86_64"
	}
	if hostOS == "" || hostArch == "" {
		panic(fmt.Sprintf("cannot run release from OS/Arch: %s/%s", hostOS, hostArch))
	}
}
