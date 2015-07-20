// Copyright 2013 The go-github AUTHORS. All rights reserved.
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

	fmt.Println("Recently updated repositories owned by user willnorris:")

	opt := &github.RepositoryListOptions{Type: "owner", Sort: "updated", Direction: "desc"}
	repos, _, err := client.Repositories.List("willnorris", opt)
	if err != nil {
		fmt.Printf("error: %v\n\n", err)
	} else {
		fmt.Printf("%v\n\n", github.Stringify(repos))
	}

	rate, _, err := client.RateLimit()
	if err != nil {
		fmt.Printf("Error fetching rate limit: %#v\n\n", err)
	} else {
		fmt.Printf("API Rate Limit: %#v\n\n", rate)
	}
}
