#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "2" ]
then
    die "$0: Received $# args... version and release (true or false) required"
fi

VERSION=$1
RELEASE=$2;

echo "RELEASE flag is $RELEASE"
./installerBuild.bash $VERSION "-Dsun.arch.data.model=64 -Pmac,-linux,-windows" $RELEASE || die "Could not build!!"

install4jc -v --mac-keystore-password=$INSTALL4J_MAC_PASS -m macos -r $VERSION ./install/lantern.install4j || die "Could not build installer?"

git=`git rev-parse HEAD | cut -c1-7`
name=lantern-$VERSION-$git.dmg
mv install/Lantern.dmg $name || die "Could not move new installer -- failed to create somehow?"
./installMetaRefresh.bash osx $name latest.dmg $RELEASE || die "ERROR: Could not build meta-refresh redirect file"

