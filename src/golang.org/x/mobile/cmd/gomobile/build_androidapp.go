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

func goAndroidBuild(pkg *build.Package) error {
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
			JavaPkgPath: "org.golang.todo." + libName,
			Name:        libName,
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

	err = goBuild(
		pkg.ImportPath,
		androidArmEnv,
		"-buildmode=c-shared",
		"-o", libPath,
	)
	if err != nil {
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

	if buildO == "" {
		buildO = filepath.Base(pkg.Dir) + ".apk"
	}
	if !strings.HasSuffix(buildO, ".apk") {
		return fmt.Errorf("output file name %q does not end in '.apk'", buildO)
	}
	var out io.Writer
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

	w, err = apkwcreate("classes.dex")
	if err != nil {
		return err
	}
	dexData, err := base64.StdEncoding.DecodeString(dexStr)
	if err != nil {
		log.Fatal("internal error bad dexStr: %v", err)
	}
	if _, err := w.Write(dexData); err != nil {
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

	if pkgImportsAL(pkg) {
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
		err = filepath.Walk(assetsDir, func(path string, info os.FileInfo, err error) error {
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
		if err != nil {
			return fmt.Errorf("asset %v", err)
		}
	}

	// TODO: add gdbserver to apk?

	if !buildN {
		if err := apkw.Close(); err != nil {
			return err
		}
	}

	return nil
}

var importsALPkg = make(map[string]struct{})

// pkgImportsAL returns true if the given package or one of its
// dependencies imports the x/mobile/exp/audio/al package.
func pkgImportsAL(pkg *build.Package) bool {
	for _, path := range pkg.Imports {
		if path == "C" {
			continue
		}
		if _, ok := importsALPkg[path]; ok {
			continue
		}
		importsALPkg[path] = struct{}{}
		if strings.HasPrefix(path, "golang.org/x/mobile/exp/audio/al") {
			return true
		}
		dPkg, err := ctx.Import(path, "", build.ImportComment)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error reading OpenAL library: %v", err)
			os.Exit(2)
		}
		if pkgImportsAL(dPkg) {
			return true
		}
	}
	return false
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
