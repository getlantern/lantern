#!/bin/bash

echo "Generating UI resources for embedding"

go install github.com/getlantern/tarfs/tarfs
dest="src/github.com/getlantern/flashlight/ui/resources.go"
echo "// +build prod" > $dest
echo " " >> $dest
tarfs -pkg ui src/github.com/getlantern/lantern-ui/app >> $dest 
