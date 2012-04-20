#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "1" ]
then
    die "$0: Received $# args... version required"
fi

VERSION=$1
./osxInstall.bash $VERSION || die "Could not build OSX"
./winInstall.bash $VERSION || die "Could not build windows"
./debInstall32Bit.bash $VERSION || die "Could not build linux 32 bit"
./debInstall64Bit.bash $VERSION || die "Could not build linux 64 bit"


