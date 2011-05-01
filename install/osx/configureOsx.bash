#!/usr/bin/env bash

function die() {
  echo "Failure: $@"
  exit 1
}

echo "First arg is: $1"
echo "Running as `whoami`"
echo "USER is $USER"
echo "User name is $userName"
echo "Executing perl replace on Info.plist"
perl -pi -e "s/<dict>/<dict><key>LSUIElement<\/key><string>1<\/string>/g" /Applications/Lantern.app/Contents/Info.plist || die "Could not fix Info.plist"

echo "Running in `pwd`"

#PLIST_DIR=/Library/LaunchAgents
PLIST_DIR=~/Library/LaunchAgents
PLIST_FILE=org.bns.lantern.plist
PLIST_INSTALL_FULL=/Applications/Lantern.app/Contents/Resources/app/$PLIST_FILE
LAUNCHD_PLIST=$PLIST_DIR/$PLIST_FILE

echo "Copying launchd plist file"
cp $PLIST_INSTALL_FULL $PLIST_DIR || die "Could not copy plist file from $PLIST_INSTALL_FULL to $PLIST_DIR"

echo "Changing permissions on launchd plist file"
chmod 644 $LAUNCHD_PLIST || die "Could not change permissions"

echo "Unloading launchd plist file just in case"

# Attempt to unload in case an old one is there
launchctl unload -F $LAUNCHD_PLIST 

echo "Loading launchd plist file"
launchctl load -F $LAUNCHD_PLIST || die "Could not load plist via launchctl"

exit 0
