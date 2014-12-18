#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "0" ]
then
    die "$0: Received $# args, none expected (I now get version from pom.xml)"
fi


./copypt.bash || die "Could not copy pluggable transports?"

VERSION=$(./parseversionfrompom.py | sed s/-SNAPSHOT//)

mvn release:clean || die "Could not clean release?"
mvn release:prepare || die "Could not prepare release?"

git=`git rev-parse --verify lantern-$VERSION^{commit} | cut -c1-7` || die "Could not get git version?"
echo "Tagging newest release at $git"
git tag -f -a latest -m "The most recent official Lantern release." $git || die "Could not tag newest?" 

echo "Pushing tags..."
git push -f --tags || die "Could not push newest tag?"

#echo "Creating branch $1"
#git branch $1 lantern-$1 || die "Could not create a branch"
#git push origin $1 || die "Could not push new branch"

# We don't care about actually releasing -- just running the tests, tagging, 
# incrementing the version -- so cleanup
mvn release:clean

# Update to the newest commited code
git pull || die "Could not pull?"

echo "Finished. You can release from the tag $VERSION"
