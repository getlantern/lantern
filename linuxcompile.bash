#!/bin/bash

./genassets.bash

# The VERSION is set to the tag for the current commit (if it exists) otherwise
# just the commit id.
VERSION="`git describe --abbrev=0 --tags --exact-match || git rev-parse --short HEAD`"
BUILD_DATE="`date -u +%Y%m%d%.%H%M%S`"
echo "Building flashlight version $VERSION ($BUILD_DATE)"
# Compile for Linux
go build -o lantern_linux -tags="prod" -ldflags="-linkmode internal -extldflags \"-static\" -w -X main.version $VERSION -X main.buildDate $BUILD_DATE" github.com/getlantern/flashlight