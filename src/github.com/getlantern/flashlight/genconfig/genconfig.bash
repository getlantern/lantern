#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

go run genconfig.go -blacklist="blacklist.txt" -masquerades="masquerades.txt" -proxiedsites="proxiedsites" -fallbacks="fallbacks.yaml" || die "Could not generate config?"

mkdir lantern-yaml-temp || die "Could not make directory"
cp lantern.yaml lantern-yaml-temp || die "Could not copy yaml"
go install github.com/getlantern/tarfs/tarfs || die "Could not install tarfs"
echo "// +build !stub" > ../config/resources.go
tarfs -pkg config lantern-yaml-temp >> ../config/resources.go

rm -rf lantern-yaml-temp
