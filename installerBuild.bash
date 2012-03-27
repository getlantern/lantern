#!/usr/bin/env bash

CONSTANTS_FILE=src/main/java/org/lantern/LanternConstants.java
function die() {
  echo $*
  echo "Reverting version file"
  git checkout $CONSTANTS_FILE || die "Could not revert version file?"
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Received $# args... version required"
fi

VERSION=$1
MVN_ARGS=$2
echo "*******MAVEN ARGS*******: $MVN_ARGS"
perl -pi -e "s/lantern_version_tok/$VERSION/g" $CONSTANTS_FILE
GE_API_KEY=`cat lantern_getexceptional.txt`
if [ ! -n "$GE_API_KEY" ]
  then
  die "No API key!!" 
fi

perl -pi -e "s/ExceptionalUtils.NO_OP_KEY/\"$GE_API_KEY\"/g" $CONSTANTS_FILE

git up || die "Could not update git"
mvn clean || die "Could not clean?"
mvn $MVN_ARGS install -Dmaven.test.skip=true || die "Could not build?"

echo "Reverting version file"
git checkout $CONSTANTS_FILE || die "Could not revert version file?"

cp target/lantern-*-jar-with-dependencies.jar install/common/lantern.jar || die "Could not copy jar?"

git tag -a v$VERSION -m "Version $VERSION release with MVN_ARGS $MVN_ARGS"
