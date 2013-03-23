#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "2" ]
then
    die "$0: Received $# args... version and release (true or false) required"
fi

RELEASE=$2;

VERSION=$1
#INSTALL4J_MAC_PASS=$2

./installerBuild.bash $VERSION "" $RELEASE || die "Could not build!!"

#install4jc -L $INSTALL4J_KEY || die "Could not update license information?"

install4jc -v --mac-keystore-password=$INSTALL4J_MAC_PASS -m macos -r $VERSION ./install/lantern.install4j || die "Could not build installer?"

#/Applications/install4j\ 5/bin/install4jc -m macos -r $VERSION ./install/lantern.install4j

name=lantern-$VERSION.dmg
mv install/Lantern.dmg $name
./installMetaRefresh.bash osx $name latest.dmg $RELEASE || die "ERROR: Could not build meta-refresh redirect file"

