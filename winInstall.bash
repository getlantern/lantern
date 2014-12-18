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
rm -rf src/main/pt/pt
cp -R install/win/pt src/main/pt/ || die "Could not copy pluggable transports!"
source ./installerBuild.bash $VERSION "-Dsun.arch.data.model=32 -Pwindows,-mac,-linux" $RELEASE || die "Could not build?"

install4jc -v --win-keystore-password=$INSTALL4J_WIN_PASS -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"

git=`git rev-parse --verify lantern-$VERSION^{commit} | cut -c1-7`
name=lantern-$VERSION-$git.exe
mv install/Lantern.exe $name || die "Could not move new installer -- failed to create somehow?"
./deployBinaries.bash $name lantern-installer.exe $RELEASE || die "ERROR: Could not deploy binaries"
