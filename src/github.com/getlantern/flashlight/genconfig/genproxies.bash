#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

echo "Generating proxies..."
cd $HOME/lantern_aws/etc
git checkout master || die "Could not checkout master?"
git pull || die "Could not pull latest code?"
./fetchcfg.py sea > proxies.yaml || die "Could not fetch proxy in sea region?"
./fetchcfg.py etc >> proxies.yaml || die "Could not fetch proxy in etc region?"
cd -

go install github.com/getlantern/tarfs/tarfs || die "Could not install tarfs"

mkdir proxies-yaml-temp || die "Could not make proxies temp dir"
cp $HOME/lantern_aws/etc/proxies.yaml proxies-yaml-temp || die "Could not copy proxies.yaml"

tarfs -pkg config -var EmbeddedProxies proxies-yaml-temp > ../config/embeddedProxies.go
git add ../config/embeddedProxies.go || die "Could not add proxies?"

rm -rf proxies-yaml-temp

echo "Finished generating proxies and added ../config/embeddedProxies.go. Please simply commit that file after confirming the process seemed to have correctly generatated everything -- check lantern.yaml in particular, but no need to check that in"
