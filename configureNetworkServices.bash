#!/usr/bin/env bash

mkdir -p ~/Library/Logs/Lantern

function log() {
  echo "`date`: $@" >> ~/Library/Logs/Lantern/installer.log
}

log "Configuring network services"
onOff=$1
url=$2
#port=$3
log "Setting to on or off: $onOff"
commandline=()
while read s;
do
    log "Configuring network: $s"
    commandline+=(-setautoproxyurl "${s}" "$url" -setautoproxystate "${s}" "${onOff}")
done < <(networksetup -listallnetworkservices | tail +2)
cleaned_commandline=`printf \""%s\" " "${commandline[@]}"`
networksetup "${commandline[@]}" || log "Could not configure network services; cmdline is $cleaned_commandline"
log "Done configuring network services!!"


