#!/usr/bin/env bash

function die() {
  echo "$@"
  exit 1
}

if [ $# -lt "3" ]
then
    die "$0: Received $# args... gpg password, git user name, and git password required"
fi

gpgpass=$1
gituser=$2
gitpass=$3
mvn release:clean || die "Could not clean?"

releasePrepare.exp $gpgpass $gituser $gitpass || die "Could not prepare release"
releasePerform.exp $gpgpass || die "Could not perform release"
#mvn release:prepare || die "Could not prepare?"
#mvn release:perform || die "Could not perform?"

pushd target/checkout/ || die "Could not cd?"
mvn nexus-staging:release || die "Could not release?"
popd
