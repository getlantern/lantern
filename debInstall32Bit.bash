#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
    die "$0: Received $# args... version and whether or not this is a release required"
fi

test -d install/linux/lib || mkdir -p install/linux/lib || die "Could not create install/linux/lib"
cp lib/linux/x86/libunix-java.so install/linux/lib/  || die "Could not copy libunix?"
rm -rf src/main/pt/pt
cp -R install/linux_x86_32/pt src/main/pt/ || die "Could not copy pluggable transports!"
./debInstall.bash $* 32 690
rm install/linux/lib/*
