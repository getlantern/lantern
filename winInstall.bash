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
/Applications/install4j\ 5/bin/install4jc -m windows -r $VERSION ./install/lantern.install4j || die "Could not build installer"

name=lantern-$VERSION.exe
mv install/Lantern.exe $name
echo "Uploading to http://cdn.bravenewsoftware.org/$name..."
aws -putp lantern $name
echo "Uploaded lantern to http://cdn.bravenewsoftware.org/$name"
echo "Also available at http://lantern.s3.amazonaws.com/$name"
