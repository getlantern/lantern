// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"go/build"
	"io"
	"io/ioutil"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

func goIOSBind(pkgs []*build.Package) error {
	typesPkgs, err := loadExportData(pkgs, darwinArmEnv)
	if err != nil {
		return err
	}

	binder, err := newBinder(typesPkgs)
	if err != nil {
		return err
	}
	name := binder.pkgs[0].Name()
	title := strings.Title(name)

	if buildO != "" && !strings.HasSuffix(buildO, ".framework") {
		return fmt.Errorf("static framework name %q missing .framework suffix", buildO)
	}
	if buildO == "" {
		buildO = title + ".framework"
	}

	srcDir := filepath.Join(tmpdir, "src")
	for _, pkg := range typesPkgs {
		if err := binder.GenGo(pkg, srcDir); err != nil {
			return err
		}
	}
	mainFile := filepath.Join(tmpdir, "src/iosbin/main.go")
	err = writeFile(mainFile, func(w io.Writer) error {
		return iosBindTmpl.Execute(w, pkgs)
	})
	if err != nil {
		return fmt.Errorf("failed to create the binding package for iOS: %v", err)
	}

	objcDir := filepath.Join(tmpdir, "objc")
	fileBases := make([]string, len(typesPkgs))
	for i, pkg := range typesPkgs {
		if fileBases[i], err = binder.GenObjc(pkg, objcDir); err != nil {
			return err
		}
	}

	cmd := exec.Command("xcrun", "lipo", "-create")

	for _, env := range [][]string{darwinArmEnv, darwinArm64Env, darwinAmd64Env} {
		arch := archClang(getenv(env, "GOARCH"))
		path, err := goIOSBindArchive(name, mainFile, env, fileBases)
		if err != nil {
			return fmt.Errorf("darwin-%s: %v", arch, err)
		}
		cmd.Args = append(cmd.Args, "-arch", arch, path)
	}

	// Build static framework output directory.
	if err := removeAll(buildO); err != nil {
		return err
	}
	headers := buildO + "/Versions/A/Headers"
	if err := mkdir(headers); err != nil {
		return err
	}
	if err := symlink("A", buildO+"/Versions/Current"); err != nil {
		return err
	}
	if err := symlink("Versions/Current/Headers", buildO+"/Headers"); err != nil {
		return err
	}
	if err := symlink("Versions/Current/"+title, buildO+"/"+title); err != nil {
		return err
	}

	cmd.Args = append(cmd.Args, "-o", buildO+"/Versions/A/"+title)
	if err := runCmd(cmd); err != nil {
		return err
	}

	// Copy header file next to output archive.
	headerFiles := make([]string, len(fileBases))
	if len(fileBases) == 1 {
		headerFiles[0] = title + ".h"
		err = copyFile(
			headers+"/"+title+".h",
			tmpdir+"/objc/"+bindPrefix+title+".h",
		)
		if err != nil {
			return err
		}
	} else {
		for i, fileBase := range fileBases {
			headerFiles[i] = fileBase + ".h"
			err = copyFile(
				headers+"/"+fileBase+".h",
				tmpdir+"/objc/"+fileBase+".h")
			if err != nil {
				return err
			}
		}
		headerFiles = append(headerFiles, title+".h")
		err = writeFile(headers+"/"+title+".h", func(w io.Writer) error {
			return iosBindHeaderTmpl.Execute(w, map[string]interface{}{
				"pkgs": pkgs, "title": title, "bases": fileBases,
			})
		})
		if err != nil {
			return err
		}
	}

	resources := buildO + "/Versions/A/Resources"
	if err := mkdir(resources); err != nil {
		return err
	}
	if err := symlink("Versions/Current/Resources", buildO+"/Resources"); err != nil {
		return err
	}
	if err := ioutil.WriteFile(buildO+"/Resources/Info.plist", []byte(iosBindInfoPlist), 0666); err != nil {
		return err
	}

	var mmVals = struct {
		Module  string
		Headers []string
	}{
		Module:  title,
		Headers: headerFiles,
	}
	err = writeFile(buildO+"/Versions/A/Modules/module.modulemap", func(w io.Writer) error {
		return iosModuleMapTmpl.Execute(w, mmVals)
	})
	if err != nil {
		return err
	}
	return symlink("Versions/Current/Modules", buildO+"/Modules")
}

const iosBindInfoPlist = `<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
      </dict>
    </plist>
`

var iosModuleMapTmpl = template.Must(template.New("iosmmap").Parse(`framework module "{{.Module}}" {
{{range .Headers}}    header "{{.}}"
{{end}}
    export *
}`))

func goIOSBindArchive(name, path string, env, fileBases []string) (string, error) {
	arch := getenv(env, "GOARCH")
	archive := filepath.Join(tmpdir, name+"-"+arch+".a")
	err := goBuild(path, env, "-buildmode=c-archive", "-tags=ios", "-o", archive)
	if err != nil {
		return "", err
	}

	objs, mfiles := make([]string, len(fileBases)), make([]string, len(fileBases))
	for i, b := range fileBases {
		objs[i], mfiles[i] = b+".o", b+".m"
	}

	args := append([]string{
		"-I", ".",
		"-g", "-O2",
		"-fobjc-arc", // enable ARC
		"-c",
	}, mfiles...)

	cmd := exec.Command(getenv(env, "CC"), args...)
	cmd.Args = append(cmd.Args, strings.Split(getenv(env, "CGO_CFLAGS"), " ")...)
	cmd.Dir = filepath.Join(tmpdir, "objc")
	cmd.Env = append([]string{}, env...)
	if err := runCmd(cmd); err != nil {
		return "", err
	}

	arArgs := append([]string{"-q", "-s", archive}, objs...)
	cmd = exec.Command("ar", arArgs...)
	cmd.Dir = filepath.Join(tmpdir, "objc")
	if err := runCmd(cmd); err != nil {
		return "", err
	}
	return archive, nil
}

var iosBindTmpl = template.Must(template.New("ios.go").Parse(`
package main

import (
	_ "golang.org/x/mobile/bind/objc"
{{range .}}	_ "../go_{{.Name}}"
{{end}}
)

import "C"

func main() {}
`))

var iosBindHeaderTmpl = template.Must(template.New("ios.h").Parse(`
// Objective-C API for talking to the following Go packages
//
{{range .pkgs}}//	{{.ImportPath}}
{{end}}//
// File is generated by gomobile bind. Do not edit.
#ifndef __{{.title}}_H__
#define __{{.title}}_H__

{{range .bases}}#include "{{.}}.h"
{{end}}
#endif
`))
