#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Received $# args... version required"
fi

VERSION=$1

#INSTALL4J_PASS=$2
./installerBuild.bash $VERSION "-Dsun.arch.data.model=32 -Pwindows" || die "Could not build?"

install4jc -L $INSTALL4J_KEY --win-keystore-password=$INSTALL4J_WIN_PASS -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"
#/Applications/install4j\ 5/bin/install4jc -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"

name=lantern-$VERSION.exe
mv install/Lantern.exe $name

./installMetaRefresh.bash win $name latest.exe false

cp $name ~/Desktop/virtual-machine-files/


