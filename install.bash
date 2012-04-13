#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

mvn --version || die "Please install maven from http://maven.apache.org" 

#pushd ..
test -d target || install_deps.bash
mvn package -Dmaven.test.skip=true || die "Could not package"
