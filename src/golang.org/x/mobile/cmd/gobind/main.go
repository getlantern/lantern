// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"flag"
	"fmt"
	"go/build"
	"log"
	"os"
)

var (
	lang   = flag.String("lang", "java", "target language for bindings, either java, go, or objc (experimental).")
	outdir = flag.String("outdir", "", "result will be written to the directory instead of stdout.")
)

var usage = `The Gobind tool generates Java language bindings for Go.

For usage details, see doc.go.`

func main() {
	flag.Parse()

	cwd, err := os.Getwd()
	if err != nil {
		log.Fatal(err)
	}
	for _, arg := range flag.Args() {
		pkg, err := build.Import(arg, cwd, 0)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", arg, err)
			os.Exit(1)
		}
		genPkg(pkg)
	}
	os.Exit(exitStatus)
}

var exitStatus = 0

func errorf(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format, args...)
	fmt.Fprintln(os.Stderr)
	exitStatus = 1
}
