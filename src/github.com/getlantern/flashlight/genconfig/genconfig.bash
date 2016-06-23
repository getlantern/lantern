#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

go run genconfig.go \
   -blacklist="blacklist.txt" \
   -masquerades="masquerades.txt" \
   -masquerades-out="../../fronted/masquerades.go" \
   -proxiedsites="proxiedsites" \
   -proxiedsites-out="../config/proxiedsites.go" \
   -fallbacks="fallbacks.yaml" \
   -fallbacks-out= "../config/fallbacks.go" \
   \
    || die "Could not generate config?"

mkdir lantern-yaml-temp || die "Could not make directory"
cp lantern.yaml lantern-yaml-temp || die "Could not copy yaml"
go install github.com/getlantern/tarfs/tarfs || die "Could not install tarfs"
echo "// +build !stub" > ../config/resources.go
tarfs -pkg config lantern-yaml-temp >> ../config/resources.go

rm -rf lantern-yaml-temp

git add ../config/resources.go || die "Could not add resources?"

echo "Finished generating resources and added ../config/resources.go. Please simply commit that file after confirming the process seemed to have correctly generatated everything -- check lantern.yaml in particular, but no need to check that in"

