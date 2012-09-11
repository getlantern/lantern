#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "3" ]
then
    die "$0: Received $# args... version osx-cert-password win-cert-passwork required"
fi

VERSION=$1
INSTALL4J_KEY_OSX=$2
INSTALL4J_KEY_WIN=$2
./osxInstall.bash $VERSION $INSTALL4J_KEY_OSX || die "Could not build OSX"
./winInstall.bash $VERSION $INSTALL4J_KEY_WIN || die "Could not build windows"
./debInstall32Bit.bash $VERSION || die "Could not build linux 32 bit"
./debInstall64Bit.bash $VERSION || die "Could not build linux 64 bit"


