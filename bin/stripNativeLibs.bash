#!/usr/bin/env bash

function die() {
    echo $*
    exit 1
}

cd ../swtlibs || die "Could not move to lib?"

for f in `ls swt*.zip`
do
  echo "Processing zip file $f"
  mkdir zip-temp || die "Could not create zip temp dir"
  mv $f zip-temp || die "Could not move zip?"
  cd zip-temp || die "Could not move to zip temp?"
  unzip $f || die "could not unzip $f"
  mv swt.jar .. || die "Could not move swt jar?"
  jarname=`echo $f | cut -f1-3 -d'.'`.jar
  echo "jar name is $jarname"
  cd -
  rm -rf zip-temp || die "Could not remove zip temp?"
  rm -rf swt-temp
  mkdir swt-temp || die "could not create swt directory?"
  mv swt.jar swt-temp
  cd swt-temp || die "could not cd to swt dir?"
  echo "Expanding jar..."
  jar xf swt.jar  
  echo "Creating new jar with no native libs..."
  jar cf swt-stripped.jar META-INF external.xpt org version.txt || die "Could not create jar!"
  cp swt-stripped.jar ../../lib/$jarname
  cp *.dll ../../install/win/
  cp *.jnilib ../../install/osx/
  cp *.so ../../install/linux/
  cd -
  rm -rf swt-temp
done
