// Copyright 2009 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main // import "9fans.net/go/games/4s"

import (
	"log"
	"os"

	"9fans.net/go/draw"
)

func main() {
	args := os.Args
	p := pieces4
	name := "4s"
	if len(args) > 1 && args[1] == "-5" {
		p = pieces5
		name = "5s"
	}

	d, err := draw.Init(nil, "", name, "")
	if err != nil {
		log.Fatal(err)
	}

	Play(p, d)
}
