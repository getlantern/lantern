// Copyright 2014 The go-github AUTHORS. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// These tests call the live GitHub API, and therefore require a little more
// setup to run.  See https://github.com/google/go-github/tree/master/tests/integration
// for more information

package tests

import (
	"fmt"
	"os"

	"code.google.com/p/goauth2/oauth"
	"github.com/google/go-github/github"
)

var (
	client *github.Client

	// auth indicates whether tests are being run with an OAuth token.
	// Tests can use this flag to skip certain tests when run without auth.
	auth bool
)

func init() {
	token := os.Getenv("GITHUB_AUTH_TOKEN")
	if token == "" {
		print("!!! No OAuth token.  Some tests won't run. !!!\n\n")
		client = github.NewClient(nil)
	} else {
		t := &oauth.Transport{
			Token: &oauth.Token{AccessToken: token},
		}
		client = github.NewClient(t.Client())
		auth = true
	}
}

func checkAuth(name string) bool {
	if !auth {
		fmt.Printf("No auth - skipping portions of %v\n", name)
	}
	return auth
}
