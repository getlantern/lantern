gobindPlugin invokes gomobile bind command on the specified package.

# Usage

build.gradle:
<pre>
plugins {
  id "org.golang.mobile.bind" version "0.2.1"
}

gobind {
  // package to bind
  pkg "github.com/someone/somepackage"

  // GOPATH
  GOPATH "/home/gopher"

  // PATH to directories with "go" and "gomobile" tools.
  PATH "path1:path2:"
}
</pre>

For details:
https://plugins.gradle.org/plugin/org.golang.mobile.bind

# TODO

* Find the stale aar file (how?)
