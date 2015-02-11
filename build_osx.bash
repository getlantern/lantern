#!/bin/bash

function die() {
  echo $*
  exit 1
}

source ./build_common.bash
go build -a -ldflags="-w -X main.version $VERSION -X main.buildDate $BUILD_DATE" github.com/getlantern/flashlight

if [ -e "Lantern.app" ]
then
	rm -Rf Lantern.app || die "Could not remove existing Lantern.app"
fi
cp -R Lantern.app_template Lantern.app || die "Could not create Lantern.app"
mv -f flashlight Lantern.app/Contents/MacOS/lantern || die "Could not move lantern into Lantern.app"
codesign -s "Developer ID Application: Brave New Software Project, Inc" Lantern.app || die "Could not code sign"

echo "About to chown Lantern.app to root:wheel, you may need to enter your password"

if [ -e "lantern.dmg" ]
then
	rm -Rf lantern.dmg || die "Could not remove existing lantern.dmg"
fi
appdmg lantern.dmg.json lantern.dmg || "Could not package Lantern.app into dmg"

