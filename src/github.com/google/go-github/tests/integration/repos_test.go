// Copyright 2014 The go-github AUTHORS. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package tests

import (
	"fmt"
	"math/rand"
	"net/http"
	"testing"

	"github.com/google/go-github/github"
)

func TestRepositories_CRUD(t *testing.T) {
	if !checkAuth("TestRepositories_CRUD") {
		return
	}

	// get authenticated user
	me, _, err := client.Users.Get("")
	if err != nil {
		t.Fatalf("Users.Get('') returned error: %v", err)
	}

	// create random repo name that does not currently exist
	var repoName string
	for {
		repoName = fmt.Sprintf("test-%d", rand.Int())
		_, resp, err := client.Repositories.Get(*me.Login, repoName)
		if err != nil {
			if resp.StatusCode == http.StatusNotFound {
				// found a non-existant repo, perfect
				break
			}
			t.Fatalf("Repositories.Get() returned error: %v", err)
		}
	}

	// create the repository
	repo, _, err := client.Repositories.Create("", &github.Repository{Name: github.String(repoName)})
	if err != nil {
		t.Fatalf("Repositories.Create() returned error: %v", err)
	}

	// update the repository description
	repo.Description = github.String("description")
	repo.DefaultBranch = nil // FIXME: this shouldn't be necessary
	_, _, err = client.Repositories.Edit(*repo.Owner.Login, *repo.Name, repo)
	if err != nil {
		t.Fatalf("Repositories.Edit() returned error: %v", err)
	}

	// delete the repository
	_, err = client.Repositories.Delete(*repo.Owner.Login, *repo.Name)
	if err != nil {
		t.Fatalf("Repositories.Delete() returned error: %v", err)
	}

	// verify that the repository was deleted
	_, resp, err := client.Repositories.Get(*repo.Owner.Login, *repo.Name)
	if err == nil {
		t.Fatalf("Test repository still exists after deleting it.")
	}
	if err != nil && resp.StatusCode != http.StatusNotFound {
		t.Fatalf("Repositories.Get() returned error: %v", err)
	}
}

func TestRepositories_BranchesTags(t *testing.T) {
	// branches
	branches, _, err := client.Repositories.ListBranches("git", "git", nil)
	if err != nil {
		t.Fatalf("Repositories.ListBranches() returned error: %v", err)
	}

	if len(branches) == 0 {
		t.Fatalf("Repositories.ListBranches('git', 'git') returned no branches")
	}

	_, _, err = client.Repositories.GetBranch("git", "git", *branches[0].Name)
	if err != nil {
		t.Fatalf("Repositories.GetBranch() returned error: %v", err)
	}

	// tags
	tags, _, err := client.Repositories.ListTags("git", "git", nil)
	if err != nil {
		t.Fatalf("Repositories.ListTags() returned error: %v", err)
	}

	if len(tags) == 0 {
		t.Fatalf("Repositories.ListTags('git', 'git') returned no tags")
	}
}

func TestRepositories_ServiceHooks(t *testing.T) {
	hooks, _, err := client.Repositories.ListServiceHooks()
	if err != nil {
		t.Fatalf("Repositories.ListServiceHooks() returned error: %v", err)
	}

	if len(hooks) == 0 {
		t.Fatalf("Repositories.ListServiceHooks() returned no hooks")
	}
}
