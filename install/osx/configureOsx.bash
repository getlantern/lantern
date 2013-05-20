#!/usr/bin/env bash


mkdir -p ~/Library/Logs/Lantern 
LOG_FILE=~/Library/Logs/Lantern/installer.log
rm $LOG_FILE

function log() {
  echo "`date`: $@" >> $LOG_FILE
}

function logFile() {
  log "Full file at $@:"
  cat "$@" >> $LOG_FILE
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

# Bug in old Lantern installers that would create a file if LaunchAgents wasn't there, so
# delete a file if we see it.
test -f $PLIST_DIR && rm $PLIST_DIR

# LaunchAgents doesn't always exist!!
test -d $PLIST_DIR || mkdir $PLIST_DIR
test -d $PLIST_DIR || die "Could not create plist dir?"

PLIST_FILE=org.lantern.plist
INSTALL_FILES=$APP_PATH/Contents/Resources/app
PLIST_INSTALL_FULL=$INSTALL_FILES/$PLIST_FILE
LAUNCHD_PLIST=$PLIST_DIR/$PLIST_FILE

test -f $PLIST_INSTALL_FULL || die "plist file does not exist at $PLIST_INSTALL_FULL?"

log "Unloading launchd plist file just in case"
# Attempt to unload in case an old one is there
launchctl unload -F $LAUNCHD_PLIST 

#log "Removing old trust store"
#test -f ~/.lantern/lantern_truststore.jks && rm -rf ~/.lantern/lantern_truststore.jks
#test -f ~/.lantern/lantern_truststore.jks && log "trust store still exists!! not good."

log "Executing perl replace on Info.plist"
# The following is done to modify the install4j-generated Info.plist to run without a UI
perl -pi -e "s/<dict>/<dict><key>LSUIElement<\/key><string>1<\/string>/g" $APP_PATH/Contents/Info.plist || die "Could not fix Info.plist"

# Just make sure the launchd Info.plist is using the correct path to our app bundle...
perl -pi -e "s:/Applications/Lantern/Lantern.app:$APP_PATH:g" $PLIST_INSTALL_FULL || die "Could not fix Info.plist"

# this is done from within install4j
#log "About to sign code...output is"
#codesign -f -s - $APP_PATH >> $LOG_FILE
#log "Signed code..."

# We also need to change the contents of the Info.plist file to reflect the correct path.
log "Running in `pwd`"


log "Copying launchd plist file"
cp $PLIST_INSTALL_FULL $PLIST_DIR || die "Could not copy plist file from $PLIST_INSTALL_FULL to $PLIST_DIR"

log "Changing permissions on launchd plist file"
chmod 644 $LAUNCHD_PLIST || die "Could not change permissions"


# We do this in  the installer proper
#log "Copying policy files"
#cp $INSTALL_FILES/local_policy.jar /System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home/lib/security/ || die "Could not copy policy file!!"
#cp $INSTALL_FILES/US_export_policy.jar /System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home/lib/security/ || die "Could not copy export policy file!!"
#log "Copied policy files"

#log "Opening app"
#open $APP_PATH || die "Could not open app bundle at $APP_PATH?"

log "Loading launchd plist file"
#launchctl load -F $LAUNCHD_PLIST || die "Could not load plist via launchctl"
#log "Loading plist for future launch on startup"
#launchctl load $LAUNCHD_PLIST || die "Could not load plist via launchctl"

#log "Copying default proxy off pac file"
#cp $APP_PATH/Contents/Resources/app/proxy_off.pac ~/.lantern/proxy.pac || die "Could not copy default pac file using APP_PATH $APP_PATH ?"
#log "Copied pac file!!"

logFile $LAUNCHD_PLIST

log "Changing owner on configureNetworkServices"
ln /usr/bin/osascript ./Lantern
./Lantern -e "do shell script \"chown root:admin $APP_PATH/Contents/Resources/app/configureNetworkServices\" with administrator privileges" || die "Could not change owner"

log "Finished configuring Lantern!"
exit 0
