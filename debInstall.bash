#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "4" ]
then
    die "$0: Received $# args... version, whether or not this is a release, architecture, and build ID required"
fi
VERSION=$1
RELEASE=$2
ARCH=$3
BUILD_ID=$4

source ./installerBuild.bash $VERSION "-Dbuildos=linux -Dsun.arch.data.model=$ARCH -Plinux,-mac,-windows" $RELEASE || die "Could not build!!"

#install4jc -m linuxDeb -r $VERSION ./install/lantern.install4j || die "Could not build Linux installer?"
install4jc -b $BUILD_ID -r $VERSION ./install/lantern.install4j || die "Could not build Linux installer?"

git=`git rev-parse --verify lantern-$VERSION^{commit} | cut -c1-7`
name=lantern-$VERSION-$ARCH-bit-$git.deb
mv install/lantern*$ARCH*.deb $name || die "Could not find built installer?"

./installMetaRefresh.bash linux $name latest-$ARCH.deb $RELEASE

#cp $name ~/Desktop/virtual-machine-files/
