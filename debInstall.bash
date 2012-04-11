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

name=lantern-$VERSION.deb
mv install/lantern_linux_*.deb $name
echo "Uploading to http://cdn.getlantern.org/$name..."
aws -putp lantern $name
echo "Uploaded lantern to http://cdn.getlantern.org/$name"
echo "Also available at http://lantern.s3.amazonaws.com/$name"


