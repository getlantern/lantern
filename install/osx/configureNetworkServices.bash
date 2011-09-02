#!/usr/bin/env bash

function log() {
  echo "`date`: $@" >> ~/Library/Logs/Lantern/installer.log
}

function die() {
  log "FAILURE: $@"
  exit 1
}

while read s; 
do 
    echo "Configuring network: $s"
    sudo networksetup -setautoproxyurl "$s" file://localhost$HOME/.lantern/proxy.pac || log "Could not set auto proxy URL for $s"
    sudo networksetup -setautoproxystate "$s" "on" || log "Could not turn auto proxy on for $s" 
done < <(networksetup -listallnetworkservices | tail +2)


