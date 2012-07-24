#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
    die "$0: Received $# args... version and cert password required"
fi

VERSION=$1
INSTALL4J_PASS=$2
./osxInstall.bash $VERSION $INSTALL4J_PASS || die "Could not build OSX"
./winInstall.bash $VERSION $INSTALL4J_PASS || die "Could not build windows"
./debInstall32Bit.bash $VERSION || die "Could not build linux 32 bit"
./debInstall64Bit.bash $VERSION || die "Could not build linux 64 bit"


