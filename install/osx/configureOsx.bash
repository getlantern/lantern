#!/usr/bin/env bash


mkdir ~/Library/Logs/Lantern
rm ~/Library/Logs/Lantern/installer.log
function log() {
  echo "`date`: $@" >> ~/Library/Logs/Lantern/installer.log
}

function logFile() {
  log "Full file at $@:"
  cat "$@" >> ~/Library/Logs/Lantern/installer.log
}

function die() {
  log "FAILURE: $@"
  exit 1
}

log "First arg is: $1"
log "Running as `whoami`"
log "USER is $USER"
log "User name is $userName"

# The following test is due to bizarre installer behavior where it installs to 
# /Applications/Lantern.app sometimes and /Applications/Lantern/Lantern.app in others.
APP_PATH=/Applications/Lantern/Lantern.app
test -d $APP_PATH || APP_PATH=/Applications/Lantern.app
#PLIST_DIR=/Library/LaunchAgents
PLIST_DIR=~/Library/LaunchAgents
PLIST_FILE=org.lantern.plist
PLIST_INSTALL_FULL=$APP_PATH/Contents/Resources/app/$PLIST_FILE
LAUNCHD_PLIST=$PLIST_DIR/$PLIST_FILE

test -f $PLIST_INSTALL_FULL || die "plist file does not exist at $PLIST_INSTALL_FULL?"

log "Unloading launchd plist file just in case"
# Attempt to unload in case an old one is there
launchctl unload -F $LAUNCHD_PLIST 

log "Removing old trust store"
test -f ~/.lantern/lantern_truststore.jks && rm -rf ~/.lantern/lantern_truststore.jks
test -f ~/.lantern/lantern_truststore.jks && log "trust store still exists!! not good."

log "Executing perl replace on Info.plist"
# The following is done to modify the install4j-generated Info.plist to run without a UI
perl -pi -e "s/<dict>/<dict><key>LSUIElement<\/key><string>1<\/string>/g" $APP_PATH/Contents/Info.plist || die "Could not fix Info.plist"
perl -pi -e "s:/Applications/Lantern/Lantern.app:$APP_PATH:g" $PLIST_INSTALL_FULL || die "Could not fix Info.plist"

# We also need to change the contents of the Info.plist file to reflect the correct path.
log "Running in `pwd`"


log "Copying launchd plist file"
cp $PLIST_INSTALL_FULL $PLIST_DIR || die "Could not copy plist file from $PLIST_INSTALL_FULL to $PLIST_DIR"

log "Changing permissions on launchd plist file"
chmod 644 $LAUNCHD_PLIST || die "Could not change permissions"


log "Loading launchd plist file"
launchctl load -F $LAUNCHD_PLIST || die "Could not load plist via launchctl"

#log "Copying default proxy off pac file"
#cp $APP_PATH/Contents/Resources/app/proxy_off.pac ~/.lantern/proxy.pac || die "Could not copy default pac file using APP_PATH $APP_PATH ?"
#log "Copied pac file!!"

logFile $LAUNCHD_PLIST

log "Finished configuring Lantern!"
exit 0
