#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export GOPATH=$DIR
export PATH=$GOPATH/bin:$PATH
