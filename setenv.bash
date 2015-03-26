#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ `uname -o` = "Cygwin" ]
then
  export GOPATH=`cygpath --windows "$DIR"`
else
  export GOPATH=$DIR
fi

export PATH=$GOPATH/bin:$PATH
