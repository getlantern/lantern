#!/bin/bash

echo "Generating UI resources for embedding"

echo "First, generating dist folder"
cd src/github.com/getlantern/lantern-ui
npm install
rm -Rf dist
gulp build
cd -

echo "Now generating resources.go"
go install github.com/getlantern/tarfs/tarfs
dest="src/github.com/getlantern/flashlight/ui/resources.go"
echo "// +build prod" > $dest
echo " " >> $dest
tarfs -pkg ui src/github.com/getlantern/lantern-ui/dist >> $dest 
