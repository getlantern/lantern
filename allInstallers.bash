#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "2" ]
then
    die "$0: Received $# args... version and release (true or false) required"
fi

VERSION=$1
RELEASE=$2;

./osxInstall.bash $VERSION $RELEASE || die "Error building OSX installer?"
./winInstall.bash $VERSION $RELEASE || die "Error building windows installer?"
./debInstall32Bit.bash $VERSION $RELEASE || die "Error building debian 32 bit installer?"
./debInstall64Bit.bash $VERSION $RELEASE || die "Error building debian 64 bit installer?"
