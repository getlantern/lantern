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

mkdir yaml-temp || die "Could not make directory"
mv lantern.yaml global.yaml
cp global.yaml yaml-temp || die "Could not copy yaml"
go install github.com/getlantern/tarfs/tarfs || die "Could not install tarfs"

tarfs -pkg config -var GlobalConfig yaml-temp >> ../config/embeddedGlobal.go

rm -rf yaml-temp

git add ../config/embeddedGlobal.go || die "Could not add resources?"

echo "Finished generating resources and added ../config/global.go. Please simply commit that file after confirming the process seemed to have correctly generatated everything -- check lantern.yaml in particular, but no need to check that in"
