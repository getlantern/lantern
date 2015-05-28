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
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

const ndkVersion = "ndk-r10d"

type version struct {
	os   string
	arch string
}

var hosts = []version{
	{"darwin", "x86"},
	{"darwin", "x86_64"},
	{"linux", "x86"},
	{"linux", "x86_64"},
	{"windows", "x86"},
	{"windows", "x86_64"},
}

var tmpdir string

func main() {
	var err error
	tmpdir, err = ioutil.TempDir("", "gomobile-release-")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(tmpdir)

	for _, host := range hosts {
		if err := mkpkg(host); err != nil {
			log.Fatal(err)
		}
	}

	if err := mkALPkg(); err != nil {
		log.Fatal(err)
	}
}

func run(dir, path string, args ...string) error {
	cmd := exec.Command(path, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func mkALPkg() (err error) {
	alTmpDir, err := ioutil.TempDir("", "openal-release-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(alTmpDir)

	if err := run(alTmpDir, "git", "clone", "-v", "git://repo.or.cz/openal-soft.git", alTmpDir); err != nil {
		return err
	}
	if err := run(alTmpDir, "git", "checkout", "19f79be57b8e768f44710b6d26017bc1f8c8fbda"); err != nil {
		return err
	}
	if err := run(filepath.Join(alTmpDir, "cmake"), "cmake", "..", "-DCMAKE_TOOLCHAIN_FILE=../XCompile-Android.txt", "-DHOST=arm-linux-androideabi"); err != nil {
		return err
	}
	if err := run(filepath.Join(alTmpDir, "cmake"), "make"); err != nil {
		return err
	}

	// Build the tarball.
	f, err := os.Create("gomobile-openal-soft-1.16.0.1.tar.gz")
	if err != nil {
		return err
	}
	bw := bufio.NewWriter(f)
	zw, err := gzip.NewWriterLevel(bw, gzip.BestCompression)
	if err != nil {
		return err
	}
	tw := tar.NewWriter(zw)
	defer func() {
		err2 := f.Close()
		if err == nil {
			err = err2
		}
	}()
	defer func() {
		err2 := bw.Flush()
		if err == nil {
			err = err2
		}
	}()
	defer func() {
		err2 := zw.Close()
		if err == nil {
			err = err2
		}
	}()
	defer func() {
		err2 := tw.Close()
		if err == nil {
			err = err2
		}
	}()

	files := map[string]string{
		"cmake/libopenal.so": "lib/armeabi/libopenal.so",
		"include/AL/al.h":    "include/AL/al.h",
		"include/AL/alc.h":   "include/AL/alc.h",
		"COPYING":            "include/AL/COPYING",
	}
	for src, dst := range files {
		f, err := os.Open(filepath.Join(alTmpDir, src))
		if err != nil {
			return err
		}
		fi, err := f.Stat()
		if err != nil {
			return err
		}
		if err := tw.WriteHeader(&tar.Header{
			Name: dst,
			Mode: int64(fi.Mode()),
			Size: fi.Size(),
		}); err != nil {
			return err
		}
		_, err = io.Copy(tw, f)
		if err != nil {
			return err
		}
		f.Close()
	}
	return nil
}

func mkpkg(host version) (err error) {
	ndkName := "android-" + ndkVersion + "-" + host.os + "-" + host.arch + "."
	if host.os == "windows" {
		ndkName += "exe"
	} else {
		ndkName += "bin"
	}
	url := "http://dl.google.com/android/ndk/" + ndkName
	log.Printf("%s\n", url)
	binPath := tmpdir + "/" + ndkName
	if err := fetch(binPath, url); err != nil {
		log.Fatal(err)
	}

	src := tmpdir + "/" + host.os + "-" + host.arch + "-src"
	dst := tmpdir + "/" + host.os + "-" + host.arch + "-dst"
	if err := os.Mkdir(src, 0755); err != nil {
		return err
	}
	if err := inflate(src, binPath); err != nil {
		return err
	}

	// The NDK is unpacked into tmpdir/linux-x86_64-src/android-ndk-r10d.
	// Move the files we want into tmpdir/linux-x86_64-dst/android-ndk-r10d.
	// We preserve the same file layout to make the full NDK interchangable
	// with the cut down file.
	usr := "android-" + ndkVersion + "/platforms/android-15/arch-arm/usr"
	gcc := "android-" + ndkVersion + "/toolchains/arm-linux-androideabi-4.8/prebuilt/"
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
	if err := move(dst+"/"+usr, src+"/"+usr, "include", "lib"); err != nil {
		return err
	}
	if err := move(dst+"/"+gcc, src+"/"+gcc, "bin", "lib", "libexec", "COPYING", "COPYING.LIB"); err != nil {
		return err
	}

	// Build the tarball.
	f, err := os.Create("gomobile-ndk-r10d-" + host.os + "-" + host.arch + ".tar.gz")
	if err != nil {
		return err
	}
	bw := bufio.NewWriter(f)
	zw, err := gzip.NewWriterLevel(bw, gzip.BestCompression)
	if err != nil {
		return err
	}
	tw := tar.NewWriter(zw)
	defer func() {
		err2 := f.Close()
		if err == nil {
			err = err2
		}
	}()
	defer func() {
		err2 := bw.Flush()
		if err == nil {
			err = err2
		}
	}()
	defer func() {
		err2 := zw.Close()
		if err == nil {
			err = err2
		}
	}()
	defer func() {
		err2 := tw.Close()
		if err == nil {
			err = err2
		}
	}()

	readme := "Stripped down copy of:\n\n\t" + url + "\n\nGenerated by golang.org/x/mobile/cmd/gomobile/release.go."
	err = tw.WriteHeader(&tar.Header{
		Name: "README",
		Mode: 0644,
		Size: int64(len(readme)),
	})
	if err != nil {
		return err
	}
	_, err = tw.Write([]byte(readme))
	if err != nil {
		return err
	}

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
			//log.Printf("linking %s to %s", name, dst)
			return tw.WriteHeader(&tar.Header{
				Name:     name,
				Linkname: dst,
				Typeflag: tar.TypeSymlink,
			})
		}
		//log.Printf("writing %s (%d)", name, fi.Size())
		err = tw.WriteHeader(&tar.Header{
			Name: name,
			Mode: int64(fi.Mode()),
			Size: fi.Size(),
		})
		if err != nil {
			return err
		}
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		_, err = io.Copy(tw, f)
		f.Close()
		return err
	})
}

func fetch(dst, url string) error {
	f, err := os.OpenFile(dst, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0755)
	if err != nil {
		return err
	}
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	_, err = io.Copy(f, resp.Body)
	err2 := resp.Body.Close()
	err3 := f.Close()
	if err != nil {
		return err
	}
	if err2 != nil {
		return err2
	}
	return err3
}

func inflate(dst, path string) error {
	p7zip := "7z"
	if runtime.GOOS == "darwin" {
		p7zip = "/Applications/Keka.app/Contents/Resources/keka7z"
	}
	cmd := exec.Command(p7zip, "x", path)
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
