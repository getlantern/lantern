#!/bin/bash

function die() {
  echo $*
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

<<<<<<< HEAD
if [[ "$OSTYPE" == "cygwin" ]]; 
=======
if [ `uname -o` = "Cygwin" ]
>>>>>>> 3a7419246fca71e4c97705648064a538b18d1455
then
  go env | grep GOARCH | cut -d = -f 2 | grep 386 || die "Lantern on Windows requires Go for 386. Please reinstall from an installer at https://golang.org/dl/ or build from source"
  export GOPATH=`cygpath --windows "$DIR"`
else
  export GOPATH=$DIR
fi

export PATH=$GOPATH/bin:$PATH
