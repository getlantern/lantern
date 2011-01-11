#!/usr/bin/env bash

function die() {
  echo "Failure: $@"
  exit 1
}

perl -pi -e "s/<dict>/<dict><key>LSUIElement<\/key><string>1<\/string>/g" /Applications/Lantern.app/Contents/Info.plist || die "Could not fix Info.plist"

PLIST_DIR=/Library/LaunchAgents
PLIST_FILE=org.bns.lantern.plist
LAUNCHD_PLIST=$PLIST_DIR/$PLIST_FILE

cp $PLIST_FILE $PLIST_DIR || die "Could not copy plist file"

chmod 644 $LAUNCHD_PLIST || die "Could not change permissions"

launchctl load -F $LAUNCHD_PLIST || die "Could not load plist via launchctl"

