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
	"path/filepath"
)

var (
	lang   = flag.String("lang", "java", "target language for bindings, either java or go.")
	output = flag.String("output", "", "result will be written to the file instead of stdout.")
)

var usage = `The Gobind tool generates Java language bindings for Go.

For usage details, see doc.go.`

func main() {
	flag.Parse()

	w := os.Stdout
	if *output != "" {
		if err := os.MkdirAll(filepath.Dir(*output), 0755); err != nil {
			fmt.Fprintf(os.Stderr, "invalid output file: %v\n", err)
			os.Exit(1)
		}

		f, err := os.Create(*output)
		if err != nil {
			fmt.Fprintf(os.Stderr, "invalid output file: %v\n", err)
			os.Exit(1)
		}
		w = f
	}

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
		genPkg(w, pkg)
	}

	if err := w.Close(); err != nil {
		errorf("error in closing output: %v", err)
	}

	os.Exit(exitStatus)
}

var exitStatus = 0

func errorf(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, format, args...)
	fmt.Fprintln(os.Stderr)
	exitStatus = 1
}
