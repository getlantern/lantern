#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

mkdir -p temp || die "Could not make directory"
cp ../app/libs/libflashlight.aar temp || die "Could not find lantern library"
cd temp
jar xf libflashlight.aar
cp classes.jar ../libs
cp -r jni ../libs

rm -rf temp
