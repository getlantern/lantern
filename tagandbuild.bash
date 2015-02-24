#!/bin/bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Tag required"
fi

if [ -z "$BNS_CERT" ]
then
    die "$0: Please set BNS_CERT to the bns signing certificate for windows"
fi

if [ -z "$BNS_CERT_PASS" ]
then
    die "$0: Please set BNS_CERT_PASS to the password for the $BNS_CERT signing key"
fi

git tag -a "$1" -f --annotate -m"Tagged $1"
git push --tags -f
UPDATE_DIST=true source ./crosscompile.bash
./package_osx.bash $VERSION_STRING
./package_win.bash $VERSION_STRING