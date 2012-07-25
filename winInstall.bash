#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "2" ]
then
    die "$0: Received $# args... version and cert password required"
fi

VERSION=$1

INSTALL4J_PASS=$2
./installerBuild.bash $VERSION "-Dsun.arch.data.model=32 -Pwindows" || die "Could not build?"

/Applications/install4j\ 5/bin/install4jc --win-keystore-password=$INSTALL4J_PASS -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"
#/Applications/install4j\ 5/bin/install4jc -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"

name=lantern-$VERSION.exe
mv install/Lantern.exe $name
echo "Uploading to http://cdn.getlantern.org/$name..."
aws -putp lantern $name
echo "Uploaded lantern to http://cdn.getlantern.org/$name"
echo "Also available at http://lantern.s3.amazonaws.com/$name"
