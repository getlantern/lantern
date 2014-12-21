#!/bin/bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Tag required"
fi

git tag -a "$1" -f --annotate -m"Tagged $1"
git push --tags -f
./crosscompile.bash