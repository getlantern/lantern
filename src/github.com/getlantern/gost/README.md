MWT EDITS

gost
==========
gost is like a vendoring `go get` that uses Git subtrees. It is useful for
producing repeatable builds and for making coordinated changes across multiple
Go packages hosted on GitHub.

When you `gost get`, any packages that are hosted on GitHub will be sucked in as
subrepositories and any other packages will be included in source form.

Unlike most vendoring mechanisms, gost is not meant to be used within a
subfolder of an existing repo. Rather, to use gost, set up a new project (which
we call a "gost repo") in order to do your vendoring in there.

A gost repo is a self-contained, versioned Go workspace, with its own src, pkg
and bin folders. In fact, you can think of gost as nothing more than a way of
versioning Go workspaces.

### Example

#### Setting up a new gost repo

Let's say that we want to make a change to github.com/getlantern/flashlight that
requires changes to various libraries in github.com/getlantern that are used by
flashlight.

##### Install gost

```
go get github.com/getlantern/gost
```

##### Initialize a gost repo

Do this outside of your existing Go workspace(s).

```
mkdir flashlight-build
cd flashlight-build
gost init
```

##### Set the gost repo directory as your GOPATH

gost init creates a setenv.bash that sets your GOPATH and PATH to point at your
gost repo.

```
source ./setenv.bash
```

##### Gost get the main project that we're interested in

```
gost get github.com/getlantern/flashlight master
```

Note that you always have to specify the branch from which you're getting code.

At this point, we have a gost repo that incorporates flashlight and all of
its dependencies (including test dependencies). We may want to go ahead and
push upstream now.

```
git remote add origin https://github.com/getlantern/flashlight-build.git
git push -u origin master
```

##### Branch from master in preparation for making our changes

```
git checkout -b mybranch master
```

Now we make our changes.

##### Pull in another existing package

Let's say that there's an existing package on GitHub that we need to add to our
GOPATH in order to make this change. We can just `gost get` it.

```
gost get github.com/getlantern/newneededpackage master
```

##### Pull in upstream updates

If updates have been made upstream, we can pull these in using `gost get -u`.
It works just like `go get -u` and updates the target package and dependencies.

```
gost get -u github.com/getlantern/flashlight
```

##### Push our gost get project and submit a PR

```
git push --set-upstream origin mybranch
```

At this point, we can submit a pull request on GitHub, which will show all
changes to all projects in our gost repo (i.e. our GOPATH). Once the PR has
been merged to master, we can pull using git as usual.

##### Contribute changes back upstream

```
git checkout master
git pull
gost push -u github.com/getlantern/flashlight master
```

Unlike `gost get` which fetches dependencies, `gost push` only pushes the
specific package indicated in the command.

Note again that you have to specify the branch to which you want to push.

The `-u` flag tells gost to first pull from upstream before pushing. You can
omit it if you don't want to do this, but if you have upstream changes that
aren't in your local repo, the push will fail.

You can also push to multiple repos in one step. For example, to push all
packages in github.com/getlantern:

```
gost push github.com/getlantern master
```
