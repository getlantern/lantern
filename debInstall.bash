#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "3" ]
then
    die "$0: Received $# args... version, architecture, and whether or not this is a release required"
fi
VERSION=$1
RELEASE=$2
ARCH=$3

./installerBuild.bash $VERSION "-Dsun.arch.data.model=$ARCH -Plinux" $RELEASE || die "Could not build!!"

install4jc -m linuxDeb -r $VERSION ./install/lantern.install4j || die "Could not build Linux installer?"

name=lantern-$VERSION-$ARCH-bit.deb
mv install/lantern*$ARCH*.deb $name || die "Could not find built installer?"

./installMetaRefresh.bash linux $name latest-$ARCH.deb $RELEASE

#cp $name ~/Desktop/virtual-machine-files/
