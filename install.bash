#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

./copypt.bash || die "Could not copy pluggable transports?"
mvn --version || die "Please install maven from http://maven.apache.org" 

rm -f target/lantern*-small.jar || die "Could not remove old jar?"
mvn -U package -Dmaven.artifact.threads=1 -Dmaven.test.skip=true || die "Could not package"
