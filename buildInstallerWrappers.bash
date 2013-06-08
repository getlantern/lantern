#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Received $# args... version required (without full git revision)"
fi

VERSION=$1
git=`git rev-parse --verify lantern-$VERSION^{commit} | cut -c1-7`

echo "Git revision is $git"

FULL_VERSION=$1-$git

install4jc -v --win-keystore-password=$INSTALL4J_WIN_PASS --mac-keystore-password=$INSTALL4J_MAC_PASS -r $FULL_VERSION ./install/wrapper.install4j || die "Could not build installer?"


