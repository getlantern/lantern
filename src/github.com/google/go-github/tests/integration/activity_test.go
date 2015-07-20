// Copyright 2014 The go-github AUTHORS. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package tests

import (
	"testing"

	"github.com/google/go-github/github"
)

func TestActivity_Starring(t *testing.T) {
	stargazers, _, err := client.Activity.ListStargazers("google", "go-github", nil)
	if err != nil {
		t.Fatalf("Activity.ListStargazers returned error: %v", err)
	}

	if len(stargazers) == 0 {
		t.Errorf("Activity.ListStargazers('google', 'go-github') returned no stargazers")
	}

	// the rest of the tests requires auth
	if !checkAuth("TestActivity_Starring") {
		return
	}

	// first, check if already starred google/go-github
	star, _, err := client.Activity.IsStarred("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.IsStarred returned error: %v", err)
	}
	if star {
		t.Fatalf("Already starring google/go-github.  Please manually unstar it first.")
	}

	// star google/go-github
	_, err = client.Activity.Star("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.Star returned error: %v", err)
	}

	// check again and verify starred
	star, _, err = client.Activity.IsStarred("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.IsStarred returned error: %v", err)
	}
	if !star {
		t.Fatalf("Not starred google/go-github after starring it.")
	}

	// unstar
	_, err = client.Activity.Unstar("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.Unstar returned error: %v", err)
	}

	// check again and verify not watching
	star, _, err = client.Activity.IsStarred("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.IsStarred returned error: %v", err)
	}
	if star {
		t.Fatalf("Still starred google/go-github after unstarring it.")
	}
}

func TestActivity_Watching(t *testing.T) {
	watchers, _, err := client.Activity.ListWatchers("google", "go-github", nil)
	if err != nil {
		t.Fatalf("Activity.ListWatchers returned error: %v", err)
	}

	if len(watchers) == 0 {
		t.Errorf("Activity.ListWatchers('google', 'go-github') returned no watchers")
	}

	// the rest of the tests requires auth
	if !checkAuth("TestActivity_Watching") {
		return
	}

	// first, check if already watching google/go-github
	sub, _, err := client.Activity.GetRepositorySubscription("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.GetRepositorySubscription returned error: %v", err)
	}
	if sub != nil {
		t.Fatalf("Already watching google/go-github.  Please manually stop watching it first.")
	}

	// watch google/go-github
	sub = &github.Subscription{Subscribed: github.Bool(true)}
	_, _, err = client.Activity.SetRepositorySubscription("google", "go-github", sub)
	if err != nil {
		t.Fatalf("Activity.SetRepositorySubscription returned error: %v", err)
	}

	// check again and verify watching
	sub, _, err = client.Activity.GetRepositorySubscription("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.GetRepositorySubscription returned error: %v", err)
	}
	if sub == nil || !*sub.Subscribed {
		t.Fatalf("Not watching google/go-github after setting subscription.")
	}

	// delete subscription
	_, err = client.Activity.DeleteRepositorySubscription("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.DeleteRepositorySubscription returned error: %v", err)
	}

	// check again and verify not watching
	sub, _, err = client.Activity.GetRepositorySubscription("google", "go-github")
	if err != nil {
		t.Fatalf("Activity.GetRepositorySubscription returned error: %v", err)
	}
	if sub != nil {
		t.Fatalf("Still watching google/go-github after deleting subscription.")
	}
}
