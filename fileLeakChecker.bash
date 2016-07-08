#!/usr/bin/env bash

function die() {
  echo $* 
  say "$1"
  echo "Running osascript"
  osascript -e 'display alert "File leak checker script died"'
  exit 1
}

set -e

log=$1
if [[ -z $log ]]; then
  if [ "$(uname)" == "Darwin" ]; then
    log=$HOME/Library/Logs/Lantern/lantern.log
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    log=$HOME/.lantern/lantern.log
  elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    echo "WARNING: THIS IS UNTESTED ON WINDOWS -- PLEASE MAKE SURE THIS PATH IS CORRECT:"
    log="$APPDATA/Roaming/Lantern/Logs/lantern.log"
	echo $log
  fi
fi

echo "Will scan log at path $log for too many open files logs"

function notify {
  if [ "$(uname)" == "Darwin" ]; then
    say "Found too many open files!" && osascript -e 'display alert "FOUND TOO MANY OPEN FILES!! Check lsof-output in working directory"'
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    notify-send "FOUND TOO MANY OPEN FILES!! Check lsof-output in working directory"
  elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
	echo "FOUND TOO MANY OPEN FILES!! Check lsof-output in working directory"
  fi
}

function runlsof {
  for pid in `ps -ef | grep Lantern | awk '{print $2}'`
  do
    echo "Running lsof for process $pid"
    lsof -p $pid &> lsof-$pid-output
  done

  echo "Found too many open files!" && notify 
}

while true
do
  sleep 2
  test -f $log || die "Could not find file at $log"
  grep "too many open files" $log && runlsof && exit 1 
done
