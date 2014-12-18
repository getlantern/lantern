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

rm -rf src/main/pt/pt
cp -R install/osx/pt src/main/pt/ || die "Could not copy pluggable transports!"
source ./installerBuild.bash $1 "-Dsun.arch.data.model=64 -Pmac,-linux,-windows" $RELEASE || die "Could not build!!"

install4jc -v --mac-keystore-password=$INSTALL4J_MAC_PASS -m macos -r $VERSION ./install/lantern.install4j || die "Could not build installer?"

git=`git rev-parse --verify lantern-$VERSION^{commit} | cut -c1-7`
name=lantern-$VERSION-$git.dmg
mv install/Lantern.dmg $name || die "Could not move new installer -- failed to create somehow?"
./deployBinaries.bash $name lantern-installer.dmg $RELEASE || die "ERROR: Could not deploy binaries"

