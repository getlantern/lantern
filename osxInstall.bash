#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "1" ]
then
    die "$0: Received $# args... version required"
fi

VERSION_FILE=src/main/java/org/lantern/LanternConstants.java
VERSION=$1
perl -pi -e "s/lantern_version_tok/$VERSION/g" $VERSION_FILE

#cd client
mvn clean || die "Could not clean?"
mvn install -Dmaven.test.skip=true || die "Could not build?"

echo "Reverting version file"
git checkout $VERSION_FILE || die "Could not revert version file?"

#cd -
cp target/lantern-*-jar-with-dependencies.jar install/common/lantern.jar || die "Could not copy jar?"

/Applications/install4j\ 5/bin/install4jc -m macos -r $VERSION ./install/lantern.install4j

mv install/Lantern.dmg lantern-$VERSION.dmg
echo "Uploading to http://cdn.bravenewsoftware.org/lantern-$VERSION.dmg..."
aws -putp lantern lantern-$VERSION.dmg
echo "Uploaded lantern to http://cdn.bravenewsoftware.org/lantern-$VERSION.dmg"

