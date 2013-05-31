#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "1" ]
then
    die "$0: Received $# args... version required"
fi

grep "<version>$1-SNAPSHOT</version>" pom.xml || die "$1 not found in pom.xml"

mvn release:clean || die "Could not clean release?"
mvn release:prepare || die "Could not prepare release?"

#echo "Creating branch $1"
#git branch $1 lantern-$1 || die "Could not create a branch"
#git push origin $1 || die "Could not push new branch"

# We don't care about actually releasing -- just running the tests, tagging, 
# incrementing the version -- so cleanup
mvn release:clean

# Update to the latest commited code
git pull || die "Could not pull?"

echo "Finished. You can release from the tag $1"
