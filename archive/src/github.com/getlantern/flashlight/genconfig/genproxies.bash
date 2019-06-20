#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ -z "$LANTERN_AWS_PATH" ]; then
  echo "LANTERN_AWS_PATH is not set, defaults to $HOME/lantern_aws"
  lantern_aws_path=$HOME/lantern_aws
else
  lantern_aws_path=$LANTERN_AWS_PATH
fi

etc=$lantern_aws_path/etc
if [ ! -d "$etc" ]; then
  die "$etc doesn't exist or is not a directory"
fi

echo "Generating proxies..."
cd $etc
git checkout master || die "Could not checkout master?"
git pull || die "Could not pull latest code?"
git submodule update  || die "Could not update submodules?"
./fetchcfg.py sea > proxies.yaml || die "Could not fetch proxy in sea region?"
./fetchcfg.py etc >> proxies.yaml || die "Could not fetch proxy in etc region?"
cd -

go install github.com/getlantern/tarfs/tarfs || die "Could not install tarfs"

mkdir proxies-yaml-temp || die "Could not make proxies temp dir"
cp $etc/proxies.yaml proxies-yaml-temp || die "Could not copy proxies.yaml"

tarfs -pkg generated -var EmbeddedProxies proxies-yaml-temp > ../config/generated/embeddedProxies.go
git add ../config/generated/embeddedProxies.go || die "Could not add proxies?"

rm -rf proxies-yaml-temp

echo "Finished generating proxies and added ../config/generated/embeddedProxies.go. Please simply commit that file after confirming the process seemed to have correctly generatated everything -- check lantern.yaml in particular, but no need to check that in"
