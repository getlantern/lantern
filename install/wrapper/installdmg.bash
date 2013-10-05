#!/usr/bin/env bash

scriptversion=0.0.1

function appendToFile() {
  local escaped=`echo $3 | perl -MURI::Escape -lne 'print uri_escape($_)'`
  echo "Got escaped: "$escaped

  echo $2=$escaped >> $1
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
  echo "app env: $application_environment"
  local application_environment="$application_environment \
    \"LINE_NUMBER\": \"$bashLineNumber\", \
    \"GROUP\": \"$groupInfo\", \
    \"VERSION\": \"$scriptversion\"}}"

  echo "app env: $application_environment"
  local body="{${application_environment}, \"client\":{\"client\":\"exceptional-java-plugin\",\"protocol_version\":\"6\",\"version\":\"0.1\"}, ${exception}, \"request\":{}}"

  echo "BODY:\n$body"  
  echo $body > $errFile

  gzip $errFile

  curl -v -X POST -H"Content-Encoding: gzip" --data-binary @$errFile.gz \
    "https://www.exceptional.io/api/errors?api_key=9848f38fb5ad1db0784675b75b9152c87dc1eb95&protocol_version=6"
}

function die() {
  echo "Failure: $@ ... Reporting errors"
  reportErrors "$@"
  exit 1
}

echo $0
if [ $# -ne "2" ]
then
    die "$0: Received $# args... dmg and mountpoint required"
fi

dmg=$1
mountpoint=$2
#hdiutil attach -mountpoint $mountpoint $dmg || die "Could not mount dmg $dmg at $mountpoint"


#hdiutil detach $mountpoint || die "Could not UNMOUNT dmg $dmg at $mountpoint"
