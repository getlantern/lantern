#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "1" ]
then
    die "$0: Received $# args... version required"
fi

#cd client
mvn clean || die "Could not clean?"
mvn install -Dmaven.test.skip=true || die "Could not build?"
#cd -
cp target/lantern-*-jar-with-dependencies.jar install/common/lantern.jar || die "Could not copy jar?"


VERSION=$1
/Applications/install4j\ 5/bin/install4jc -m macos -r $VERSION ./install/lantern.install4j

mv install/Lantern.dmg lantern-$VERSION.dmg
aws -putp lantern lantern-$VERSION.dmg

#scp install/Lantern.exe afisk@10.0.46.68:/home/afisk || die "Could not copy file"
