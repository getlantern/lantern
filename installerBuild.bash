#!/usr/bin/env bash

CONSTANTS_FILE=src/main/java/org/lantern/LanternConstants.java
function die() {
  echo $*
  echo "Reverting version file"
  git checkout -- $CONSTANTS_FILE || die "Could not revert version file?"
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Received $# args... version required"
fi

which install4jc || die "No install4jc on PATH -- ABORTING"
printenv | grep INSTALL4J_KEY || die "Must have INSTALL4J_KEY defined with the Install4J license key to use"
printenv | grep INSTALL4J_MAC_PASS || die "Must have OSX signing key password defined in INSTALL4J_MAC_PASS"
printenv | grep INSTALL4J_WIN_PASS || die "Must have windows signing key password defined in INSTALL4J_WIN_PASS"

VERSION=$1
INTERNAL_VERSION=$1-`git rev-parse HEAD | cut -c1-10`
MVN_ARGS=$2
echo "*******MAVEN ARGS*******: $MVN_ARGS"
perl -pi -e "s/lantern_version_tok/$INTERNAL_VERSION/g" $CONSTANTS_FILE

BUILD_TIME=`date +%s`
perl -pi -e "s/build_time_tok/$BUILD_TIME/g" $CONSTANTS_FILE

GE_API_KEY=`cat lantern_getexceptional.txt`
if [ ! -n "$GE_API_KEY" ]
  then
  die "No API key!!" 
fi

perl -pi -e "s/ExceptionalUtils.NO_OP_KEY/\"$GE_API_KEY\"/g" $CONSTANTS_FILE

curBranch=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
git pull origin $curBranch || die '"git pull origin" failed?'
mvn clean || die "Could not clean?"
mvn $MVN_ARGS install -Dmaven.test.skip=true || die "Could not build?"

echo "Reverting version file"
git checkout -- $CONSTANTS_FILE || die "Could not revert version file?"

cp target/lantern*SNAPSHOT.jar install/common/lantern.jar || die "Could not copy jar?"

echo "Tagging..."
git tag -f -a v$VERSION -m "Version $INTERNAL_VERSION release with MVN_ARGS $MVN_ARGS"

echo "Pushing tags..."
git push --tags || die "Could not push tags!!"
echo "Finished push..."

install4jc -L $INSTALL4J_KEY || die "Could not update license information?"
