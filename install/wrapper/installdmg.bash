#!/usr/bin/env bash

scriptversion=0.0.2

mkdir -p ~/Library/Logs/Lantern || echo "Fould not make dir?"
touch ~/Library/Logs/Lantern/dmginstall.log || die "Could not touch log file?"

datesuffix=`date "+%Y-%m-%d%H-%M-%S"`
#mountpoint=lantern-install-$scriptversion-$datesuffix
mountpoint=/Volumes/lantern

function log() {
  echo $1 >> ~/Library/Logs/Lantern/dmginstall.log
}

function reportErrors() {
  local tmpBase=`basename $0`
  local tmpDir=`mktemp -d /tmp/${tmpBase}.XXXXXX`

  local errFile="$tmpDir/errFile"

  #appendToFile $errFile "message" "$@"
  #appendToFile $errFile "host" "`uname -a`"
  #appendToFile $errFile "disk" "`df -h`"
  #appendToFile $errFile "lineNumber" "${BASH_LINENO[1]}"

  local bashLineNumber="${BASH_LINENO[1]}"
  local uName=`uname -a`
  local diskInfo="`df -h`"

  local groupInfo=`id -Gn`
  local group=`echo "$groupInfo" | perl -MURI::Escape -lne 'print uri_escape($_)'`

  local date=`date`
  local exception="\"exception\": {\"occurred_at\":"
  local exception="$exception \"$date\", \"message\": \"$@\""
  local exception="$exception, \"backtrace\": [\""
  local exception="$exception$lineNumber\"], \"exception_class\": \""
  local exception="$exception$0\"}"

  local application_environment="\"application_environment\": {\"application_root_directory\":\"\/\",\"env\":{"
  log "app env: $application_environment"
  local application_environment="$application_environment \
    \"LINE_NUMBER\": \"$bashLineNumber\", \
    \"GROUP\": \"$groupInfo\", \
    \"VERSION\": \"$scriptversion\"}}"

  log "app env: $application_environment"
  local body="{${application_environment}, \"client\":{\"client\":\"exceptional-java-plugin\",\"protocol_version\":\"6\",\"version\":\"0.1\"}, ${exception}, \"request\":{}}"

  log "BODY:\n$body"  
  echo $body > $errFile

  gzip $errFile

  curl -v -X POST -H"Content-Encoding: gzip" --data-binary @$errFile.gz \
    "https://www.exceptional.io/api/errors?api_key=9848f38fb5ad1db0784675b75b9152c87dc1eb95&protocol_version=6"
}

function die() {
  log "Failure: $@ ... Reporting errors"
  hdiutil detach $mountpoint || echo "Could not UNMOUNT dmg $dmg at $mountpoint"
#  reportErrors "$@"
  exit 1
}

echo $0
if [ $# -ne "1" ]
then
    die "$0: Received $# args... dmg and mountpoint required"
fi

log $mountpoint

dmg=$1
log "DMG file: $dmg"

# Just in case a previous lantern dmg was attached...
hdiutil detach $mountpoint

#hdiutil attach -nobrowse $dmg || die "Could not mount dmg $dmg at $mountpoint"
#hdiutil attach -mountpoint $mountpoint $dmg -debug || die "Could not mount dmg $dmg at $mountpoint"
#hdiutil attach $dmg  || die "Could not mount dmg $dmg at $mountpoint"
hdiutil attach $dmg -debug &> /Users/afisk/Library/Logs/hdiutil.log || die "Could not mount dmg $dmg at $mountpoint"

log `ls -la $mountpoint`
apptmpdir=`mktemp -d /tmp/lantern-install.XXXXXX` || die "Could not create temp dir?"
cp -R $mountpoint/"Lantern Installer.app" $apptmpdir || die "Could not copy installer app!!"
open $apptmpdir/"Lantern Installer.app" || die "Could not open app at $apptmpdir/Lantern Installer.app" 

log "Detaching from $mountpoint"
hdiutil detach $mountpoint || die "Could not UNMOUNT dmg $dmg at $mountpoint"
#hdiutil detach /Volumes/lantern || die "Could not UNMOUNT dmg $dmg at $mountpoint"
