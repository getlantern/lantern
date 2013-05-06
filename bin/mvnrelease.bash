#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

mvn release:clean || die "Could not clean?"
mvn release:prepare || die "Could not prepare?"
mvn release:perform || die "Could not perform?"

pushd target/checkout/ || die "Could not cd?"
mvn nexus-staging:release || die "Could not release?"
popd
