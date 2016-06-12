// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"flag"
	"fmt"
	"go/importer"
	"go/types"
	"log"
	"os"
	"os/exec"
	"strings"
)

var (
	lang    = flag.String("lang", "java", "target language for bindings, either java, go, or objc (experimental).")
	outdir  = flag.String("outdir", "", "result will be written to the directory instead of stdout.")
	javaPkg = flag.String("javapkg", "", "custom Java package path used instead of the default 'go.<go package name>'. Valid only with -lang=java.")
	prefix  = flag.String("prefix", "", "custom Objective-C name prefix used instead of the default 'Go'. Valid only with -lang=objc.")
)

var usage = `The Gobind tool generates Java language bindings for Go.

For usage details, see doc.go.`

func main() {
	flag.Parse()

	if *lang != "java" && *javaPkg != "" {
		log.Fatalf("Invalid option -javapkg for gobind -lang=%s", *lang)
	} else if *lang != "objc" && *prefix != "" {
		log.Fatalf("Invalid option -prefix for gobind -lang=%s", *lang)
	}

	// Make sure the export data for the packages being compiled is up to
	// date. Also use the go tool to provide good error messages for any
	// type checking errors in the provided packages.
	cmd := exec.Command("go", "install")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Args = append(cmd.Args, flag.Args()...)
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "%s failed: %v", strings.Join(cmd.Args, " "), err)
		os.Exit(1)
	}

	var allPkg []*types.Package
	imp := importer.Default()
	for _, arg := range flag.Args() {
		pkg, err := imp.Import(arg)
		if err != nil {
			fmt.Fprintf(os.Stderr, "could not import package %s: %v", arg, err)
			os.Exit(1)
		}
		allPkg = append(allPkg, pkg)
	}
	for _, pkg := range allPkg {
		genPkg(pkg, allPkg)
	}
	os.Exit(exitStatus)
}

var exitStatus = 0

func errorf(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format, args...)
	fmt.Fprintln(os.Stderr)
	exitStatus = 1
}
