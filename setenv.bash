#!/bin/bash

function die() {
  echo $*
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [[ "$OSTYPE" == "cygwin" ]]; 
then
  export GOPATH=386 # Requires go1.5+
  export GOPATH=`cygpath --windows "$DIR"`
else
  export GOPATH=$DIR
fi

export PATH=$GOPATH/bin:$PATH
