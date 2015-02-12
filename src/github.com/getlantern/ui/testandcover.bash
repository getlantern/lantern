#!/bin/bash

# This script tests multiple packages and creates a consolidated cover profile
# See https://gist.github.com/hailiang/0f22736320abe6be71ce for inspiration.
# The list of packages to test is specified in testpackages.txt.

function die() {
  echo $*
  exit 1
}

export GOPATH=`pwd`:$GOPATH

# Initialize profile.cov
echo "mode: count" > profile.cov

# Initialize error tracking
ERROR=""

# Load environment variables with things like authentication info
source ./envvars.bash

# Test each package and append coverage profile info to profile.cov
for pkg in `cat testpackages.txt`
do
    #$HOME/gopath/bin/
    go test -v -covermode=count -coverprofile=profile_tmp.cov $pkg || ERROR="Error testing $pkg"
    tail -n +2 profile_tmp.cov >> profile.cov || die "Unable to append coverage for $pkg"
done

if [ ! -z "$ERROR" ]
then
    die "Encountered error, last error was: $ERROR"
fi

#- GOPATH=`pwd`:$GOPATH $HOME/gopath/bin/goveralls -v -service travis-ci github.com/getlantern/buuid