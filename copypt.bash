#!/usr/bin/env bash

# This script copies the pluggable transports to the resources directory for
# whatever platform we're running on. They can't go into the normal 
# src/main/resources directory because maven has filtering turned on by 
# default for resources directories, which corrupts binaries. Beyond that,
# we only want to include pluggable transports for the relevant platform 
# because we build platform-specific jars.
function die() {
  echo $*
  exit 1
}

if [ $(uname) == "Darwin" ]
then
  ls -la configureNetworkServices | grep rwsr | grep wheel || ./setNetUidOsx.bash
  ptdir=osx
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]
then
  if [ $(uname -m) == 'x86_64' ]; then
    ptdir=linux_x86_64
  else
    ptdir=linux_x86_32
  fi
elif [ -n "$COMSPEC" -a -x "$COMSPEC" ]
then
  ptdir=win	
fi

test -d src/main/pt || mkdir src/main/pt || die "Could not create pt directory?"

echo "Copying from install/$ptdir/pt to src/main/pt/"
cp -R install/$ptdir/pt src/main/pt/ || die "Could not copy pluggable transports?"
