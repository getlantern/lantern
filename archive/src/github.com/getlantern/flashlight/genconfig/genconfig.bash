#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

./genproxies.bash || die "Could not generate proxies?"
./genglobal.bash || die "Could not generate global config"
