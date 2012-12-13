#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "2" ]
then
    die "$0: Received $# args... version and whether or not it's a release (true or false) required"
fi

VERSION=$1
RELEASE=$2

echo "RELEASE flag is $RELEASE"

#INSTALL4J_PASS=$2
./installerBuild.bash $VERSION "-Dsun.arch.data.model=32 -Pwindows" $RELEASE || die "Could not build?"

install4jc --win-keystore-password="#@$|bg77q" -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"
#install4jc --win-keystore-password=$INSTALL4J_WIN_PASS -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"
#install4jc -L $INSTALL4J_KEY --win-keystore-password=$INSTALL4J_WIN_PASS -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"
#/Applications/install4j\ 5/bin/install4jc -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"

name=lantern-$VERSION.exe
mv install/Lantern.exe $name || die "Could not move new installer -- failed to create somehow?"

./installMetaRefresh.bash win $name latest.exe $RELEASE

#cp $name ~/Desktop/virtual-machine-files/


