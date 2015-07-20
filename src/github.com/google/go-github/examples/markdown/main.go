// Copyright 2014 The go-github AUTHORS. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"

	"github.com/google/go-github/github"
)

func main() {
	client := github.NewClient(nil)

	input := "# heading #\nLink to issue #1\n"
	md, _, err := client.Markdown(input, &github.MarkdownOptions{Mode: "gfm", Context: "google/go-github"})
	if err != nil {
		fmt.Printf("error: %v\n\n", err)
	}

	fmt.Printf("converted markdown:\n%v\n", md)
}
