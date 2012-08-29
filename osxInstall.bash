#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
    die "$0: Received $# args... version and cert password required"
fi

VERSION=$1
INSTALL4J_PASS=$2

./installerBuild.bash $VERSION || die "Could not build!!"


/Applications/install4j\ 5/bin/install4jc --mac-keystore-password=$INSTALL4J_PASS -m macos -r $VERSION ./install/lantern.install4j
#/Applications/install4j\ 5/bin/install4jc -m macos -r $VERSION ./install/lantern.install4j

name=lantern-$VERSION.dmg
mv install/Lantern.dmg $name
./installMetaRefresh.bash osx $name latest.dmg || die "ERROR: Could not build meta-refresh redirect file"

