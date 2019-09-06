#!/usr/bin/env bash

source setenv.bash
pushd src/github.com/getlantern/flashlight
go build && ./flashlight "$@"
popd
