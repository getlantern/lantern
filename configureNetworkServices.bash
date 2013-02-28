#!/usr/bin/env bash

mkdir ~/Library/Logs/Lantern

function log() {
  echo "`date`: $@" >> ~/Library/Logs/Lantern/installer.log
}

log "Configuring network services"
onOff=$1
url=$2
#port=$3
log "Setting to on or off: $onOff"
while read s; 
do
    log "Configuring network: $s"
    networksetup -setautoproxyurl "$s" $url || log "Could not set auto proxy URL for $s"
    networksetup -setautoproxystate "$s" "$onOff" || log "Could not turn auto proxy on for $s"
    log "Configured network: $s"
done < <(networksetup -listallnetworkservices | tail +2)
log "Done configuring network services!!"
