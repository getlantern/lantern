gobindPlugin invokes gomobile bind command on the specified package.

# Usage

build.gradle:
<pre>
plugins {
  id "org.golang.mobile.bind" version "0.2.2"
}

gobind {
  // package to bind
  pkg "github.com/someone/somepackage"

  // GOPATH
  GOPATH "/home/gopher"

  // Absolute path to the gomobile binary
  GOMOBILE "/mypath/bin/gomobile"

  // Absolute path to the go binary
  GO "/usr/local/go/bin/go"
}
</pre>

For details:
https://plugins.gradle.org/plugin/org.golang.mobile.bind

# TODO

* Find the stale aar file (how?)
