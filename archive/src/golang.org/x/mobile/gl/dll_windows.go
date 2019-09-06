// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package gl

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
)

var debug = log.New(ioutil.Discard, "gl: ", log.LstdFlags)

func downloadDLLs() (path string, err error) {
	url := "https://dl.google.com/go/mobile/angle-dd5c5b-" + runtime.GOARCH + ".tgz"
	debug.Printf("downloading %s", url)
	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("gl: %v", err)
	}
	defer func() {
		err2 := resp.Body.Close()
		if err == nil && err2 != nil {
			err = fmt.Errorf("gl: error reading body from %v: %v", url, err2)
		}
	}()
	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("gl: error fetching %v, status: %v", url, resp.Status)
		return "", err
	}

	r, err := gzip.NewReader(resp.Body)
	if err != nil {
		return "", fmt.Errorf("gl: error reading gzip from %v: %v", url, err)
	}
	tr := tar.NewReader(r)
	var bytesGLESv2, bytesEGL []byte
	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", fmt.Errorf("gl: error reading tar from %v: %v", url, err)
		}
		switch header.Name {
		case "angle-" + runtime.GOARCH + "/libglesv2.dll":
			bytesGLESv2, err = ioutil.ReadAll(tr)
		case "angle-" + runtime.GOARCH + "/libegl.dll":
			bytesEGL, err = ioutil.ReadAll(tr)
		default: // skip
		}
		if err != nil {
			return "", fmt.Errorf("gl: error reading %v from %v: %v", header.Name, url, err)
		}
	}
	if len(bytesGLESv2) == 0 || len(bytesEGL) == 0 {
		return "", fmt.Errorf("gl: did not find both DLLs in %v", url)
	}

	writeDLLs := func(path string) error {
		if err := ioutil.WriteFile(filepath.Join(path, "libglesv2.dll"), bytesGLESv2, 0755); err != nil {
			return fmt.Errorf("gl: cannot install ANGLE: %v", err)
		}
		if err := ioutil.WriteFile(filepath.Join(path, "libegl.dll"), bytesEGL, 0755); err != nil {
			return fmt.Errorf("gl: cannot install ANGLE: %v", err)
		}
		return nil
	}

	// First, we attempt to install these DLLs in LOCALAPPDATA/Shiny.
	//
	// Traditionally we would use the system32 directory, but it is
	// no longer writable by normal programs.
	os.MkdirAll(appdataPath(), 0775)
	if err := writeDLLs(appdataPath()); err == nil {
		return appdataPath(), nil
	}
	debug.Printf("DLLs could not be written to %s", appdataPath())

	// Second, install in GOPATH/pkg if it exists.
	gopath := os.Getenv("GOPATH")
	gopathpkg := filepath.Join(gopath, "pkg")
	if _, err := os.Stat(gopathpkg); err == nil && gopath != "" {
		if err := writeDLLs(gopathpkg); err == nil {
			return gopathpkg, nil
		}
	}
	debug.Printf("DLLs could not be written to GOPATH")

	// Third, pick a temporary directory.
	tmp := os.TempDir()
	if err := writeDLLs(tmp); err != nil {
		return "", fmt.Errorf("gl: unable to install ANGLE DLLs: %v", err)
	}
	return tmp, nil
}

func appdataPath() string {
	return filepath.Join(os.Getenv("LOCALAPPDATA"), "GoGL", runtime.GOARCH)
}

func findDLLs() (err error) {
	load := func(path string) (bool, error) {
		if path != "" {
			LibGLESv2.Name = filepath.Join(path, filepath.Base(LibGLESv2.Name))
			LibEGL.Name = filepath.Join(path, filepath.Base(LibEGL.Name))
		}
		if err := LibGLESv2.Load(); err == nil {
			if err := LibEGL.Load(); err != nil {
				return false, fmt.Errorf("gl: loaded libglesv2 but not libegl: %v", err)
			}
			if path == "" {
				debug.Printf("DLLs found")
			} else {
				debug.Printf("DLLs found in: %q", path)
			}
			return true, nil
		}
		return false, nil
	}

	// Look in the system directory.
	if ok, err := load(""); ok || err != nil {
		return err
	}

	// Look in the AppData directory.
	if ok, err := load(appdataPath()); ok || err != nil {
		return err
	}

	// TODO: Look for a Chrome installation.

	// Look in GOPATH/pkg.
	if ok, err := load(filepath.Join(os.Getenv("GOPATH"), "pkg")); ok || err != nil {
		return err
	}

	// Look in temporary directory.
	if ok, err := load(os.TempDir()); ok || err != nil {
		return err
	}

	// Download the DLL binary.
	path, err := downloadDLLs()
	if err != nil {
		return err
	}
	debug.Printf("DLLs written to %s", path)
	if ok, err := load(path); !ok || err != nil {
		return fmt.Errorf("gl: unable to load ANGLE after installation: %v", err)
	}
	return nil
}
