#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
    die "$0: Received $# args... version and whether or not this is a release required"
fi
#RELEASE=$2

test -d install/linux/lib || mkdir -p install/linux/lib || die "Could not create install/linux/lib"
cp lib/linux/x86_64/libunix-java.so install/linux/lib/ || die "Could not copy libunix?"
./debInstall.bash $* 64 579
rm install/linux/lib/* 
