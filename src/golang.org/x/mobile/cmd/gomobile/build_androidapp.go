// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"errors"
	"fmt"
	"go/build"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
)

func goAndroidBuild(pkg *build.Package, androidArchs []string) (map[string]bool, error) {
	appName := path.Base(pkg.ImportPath)
	libName := androidPkgName(appName)
	manifestPath := filepath.Join(pkg.Dir, "AndroidManifest.xml")
	manifestData, err := ioutil.ReadFile(manifestPath)
	if err != nil {
		if !os.IsNotExist(err) {
			return nil, err
		}

		buf := new(bytes.Buffer)
		buf.WriteString(`<?xml version="1.0" encoding="utf-8"?>`)
		err := manifestTmpl.Execute(buf, manifestTmplData{
			// TODO(crawshaw): a better package path.
			JavaPkgPath: "org.golang.todo." + libName,
			Name:        strings.Title(appName),
			LibName:     libName,
		})
		if err != nil {
			return nil, err
		}
		manifestData = buf.Bytes()
		if buildV {
			fmt.Fprintf(os.Stderr, "generated AndroidManifest.xml:\n%s\n", manifestData)
		}
	} else {
		libName, err = manifestLibName(manifestData)
		if err != nil {
			return nil, fmt.Errorf("error parsing %s: %v", manifestPath, err)
		}
	}

	libFiles := []string{}
	nmpkgs := make(map[string]map[string]bool) // map: arch -> extractPkgs' output

	for _, arch := range androidArchs {
		env := androidEnv[arch]
		toolchain := ndk.Toolchain(arch)
		libPath := "lib/" + toolchain.abi + "/lib" + libName + ".so"
		libAbsPath := filepath.Join(tmpdir, libPath)
		if err := mkdir(filepath.Dir(libAbsPath)); err != nil {
			return nil, err
		}
		err = goBuild(
			pkg.ImportPath,
			env,
			"-buildmode=c-shared",
			"-o", libAbsPath,
		)
		if err != nil {
			return nil, err
		}
		nmpkgs[arch], err = extractPkgs(toolchain.Path("nm"), libAbsPath)
		if err != nil {
			return nil, err
		}
		libFiles = append(libFiles, libPath)
	}

	block, _ := pem.Decode([]byte(debugCert))
	if block == nil {
		return nil, errors.New("no debug cert")
	}
	privKey, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}

	if buildO == "" {
		buildO = androidPkgName(filepath.Base(pkg.Dir)) + ".apk"
	}
	if !strings.HasSuffix(buildO, ".apk") {
		return nil, fmt.Errorf("output file name %q does not end in '.apk'", buildO)
	}
	var out io.Writer
	if !buildN {
		f, err := os.Create(buildO)
		if err != nil {
			return nil, err
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
	apkwCreate := func(name string) (io.Writer, error) {
		if buildV {
			fmt.Fprintf(os.Stderr, "apk: %s\n", name)
		}
		if buildN {
			return ioutil.Discard, nil
		}
		return apkw.Create(name)
	}
	apkwWriteFile := func(dst, src string) error {
		w, err := apkwCreate(dst)
		if err != nil {
			return err
		}
		if !buildN {
			f, err := os.Open(src)
			if err != nil {
				return err
			}
			defer f.Close()
			if _, err := io.Copy(w, f); err != nil {
				return err
			}
		}
		return nil
	}

	w, err := apkwCreate("AndroidManifest.xml")
	if err != nil {
		return nil, err
	}
	if _, err := w.Write(manifestData); err != nil {
		return nil, err
	}

	w, err = apkwCreate("classes.dex")
	if err != nil {
		return nil, err
	}
	dexData, err := base64.StdEncoding.DecodeString(dexStr)
	if err != nil {
		log.Fatal("internal error bad dexStr: %v", err)
	}
	if _, err := w.Write(dexData); err != nil {
		return nil, err
	}

	for _, libFile := range libFiles {
		if err := apkwWriteFile(libFile, filepath.Join(tmpdir, libFile)); err != nil {
			return nil, err
		}
	}

	for _, arch := range androidArchs {
		toolchain := ndk.Toolchain(arch)
		if nmpkgs[arch]["golang.org/x/mobile/exp/audio/al"] {
			dst := "lib/" + toolchain.abi + "/libopenal.so"
			src := dst
			if arch == "arm" {
				src = "lib/armeabi/libopenal.so"
			} else if arch == "arm64" {
				src = "lib/arm64/libopenal.so"
			}
			if err := apkwWriteFile(dst, filepath.Join(ndk.Root(), "openal/"+src)); err != nil {
				return nil, err
			}
		}
	}

	// Add any assets.
	assetsDir := filepath.Join(pkg.Dir, "assets")
	assetsDirExists := true
	fi, err := os.Stat(assetsDir)
	if err != nil {
		if os.IsNotExist(err) {
			assetsDirExists = false
		} else {
			return nil, err
		}
	} else {
		assetsDirExists = fi.IsDir()
	}
	if assetsDirExists {
		// if assets is a symlink, follow the symlink.
		assetsDir, err = filepath.EvalSymlinks(assetsDir)
		if err != nil {
			return nil, err
		}
		err = filepath.Walk(assetsDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if name := filepath.Base(path); strings.HasPrefix(name, ".") {
				// Do not include the hidden files.
				return nil
			}
			if info.IsDir() {
				return nil
			}
			name := "assets/" + path[len(assetsDir)+1:]
			return apkwWriteFile(name, path)
		})
		if err != nil {
			return nil, fmt.Errorf("asset %v", err)
		}
	}

	// TODO: add gdbserver to apk?

	if !buildN {
		if err := apkw.Close(); err != nil {
			return nil, err
		}
	}

	// TODO: return nmpkgs
	return nmpkgs[androidArchs[0]], nil
}

// androidPkgName sanitizes the go package name to be acceptable as a android
// package name part. The android package name convention is similar to the
// java package name convention described in
// https://docs.oracle.com/javase/specs/jls/se8/html/jls-6.html#jls-6.5.3.1
// but not exactly same.
func androidPkgName(name string) string {
	var res []rune
	for i, r := range name {
		switch {
		case 'a' <= r && r <= 'z', 'A' <= r && r <= 'Z':
			res = append(res, r)
		case '0' <= r && r <= '9':
			if i == 0 {
				panic(fmt.Sprintf("package name %q is not a valid go package name", name))
			}
			res = append(res, r)
		default:
			res = append(res, '_')
		}
	}
	if len(res) == 0 || res[0] == '_' {
		// Android does not seem to allow the package part starting with _.
		res = append([]rune{'g', 'o'}, res...)
	}
	s := string(res)
	// Look for Java keywords that are not Go keywords, and avoid using
	// them as a package name.
	//
	// This is not a problem for normal Go identifiers as we only expose
	// exported symbols. The upper case first letter saves everything
	// from accidentally matching except for the package name.
	//
	// Note that basic type names (like int) are not keywords in Go.
	switch s {
	case "abstract", "assert", "boolean", "byte", "catch", "char", "class",
		"do", "double", "enum", "extends", "final", "finally", "float",
		"implements", "instanceof", "int", "long", "native", "private",
		"protected", "public", "short", "static", "strictfp", "super",
		"synchronized", "this", "throw", "throws", "transient", "try",
		"void", "volatile", "while":
		s += "_"
	}
	return s
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
