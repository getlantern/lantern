#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
    die "$0: Received $# args... version and architecture required"
fi
VERSION=$1
ARCH=$2
./installerBuild.bash $VERSION "-Dsun.arch.data.model=$ARCH -Plinux" || die "Could not build!!"

/Applications/install4j\ 5/bin/install4jc -m linuxDeb -r $VERSION ./install/lantern.install4j

name=lantern-$VERSION-$ARCH-bit.deb
mv install/lantern*$ARCH*.deb $name || die "Could not find built installer?"

./installMetaRefresh.bash linux $name latest-$ARCH.deb

cp $name ~/Desktop/virtual-machine-files/
