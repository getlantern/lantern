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
GE_API_KEY=`cat ~/.lantern/lantern_getexceptional.txt`

perl -pi -e "s/GetExceptionalUtils.NO_OP_KEY/\"$GE_API_KEY\"/g" $CONSTANTS_FILE

#cd client
mvn clean || die "Could not clean?"
mvn $MVN_ARGS install -Dmaven.test.skip=true || die "Could not build?"

echo "Reverting version file"
git checkout $CONSTANTS_FILE || die "Could not revert version file?"

cp target/lantern-*-jar-with-dependencies.jar install/common/lantern.jar || die "Could not copy jar?"

