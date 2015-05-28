// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*

Godef prints the source location of definitions in Go programs.

Usage:

	godef [-t] [-a] [-A] [-o offset] [-i] [-f file][-acme] [expr]

File specifies the source file in which to evaluate expr.
Expr must be an identifier or a Go expression
terminated with a field selector.

If expr is not given, then offset specifies a location
within file, which should be within, or adjacent to
an identifier or field selector.

If the -t flag is given, the type of the expression will
also be printed. The -a flag causes all the public
members (fields and methods) of the expression,
and their location, to be printed also; the -A flag
prints private members too.

If the -i flag is specified, the source is read
from standard input, although file must still
be specified so that other files in the same source
package may be found.

If the -acme flag is given, the offset, file name and contents
are read from the current acme window.

Example:

	$ cd $GOROOT
	$ godef -f src/pkg/xml/read.go 'NewParser().Skip'
	src/pkg/xml/read.go:384:18
	$

*/
package main
