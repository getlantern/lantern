#!/bin/bash

./genassets.bash

# The VERSION is set to the tag for the current commit (if it exists) otherwise
# just the commit id.
VERSION="`git describe --abbrev=0 --tags --exact-match || git rev-parse --short HEAD`"
BUILD_DATE="`date -u +%Y%m%d%.%H%M%S`"
echo "Building flashlight version $VERSION ($BUILD_DATE)"
# gox -ldflags="-w -X main.version $VERSION -X main.buildDate $BUILD_DATE" -osarch="linux/386 linux/amd64 windows/386 darwin/amd64" github.com/getlantern/flashlight
# Compile for Mac
gox -tags="prod" -ldflags="-w -X main.version $VERSION -X main.buildDate $BUILD_DATE" -osarch="darwin/amd64" -output="lantern_{{.OS}}_{{.Arch}}" github.com/getlantern/flashlight
# Compile for Windows (use -H=windowsgui ldflag to make this a Windows instead of a console app)
gox -tags="prod" -ldflags="-w -X main.version $VERSION -X main.buildDate $BUILD_DATE -H=windowsgui" -osarch="windows/386" -output="lantern_{{.OS}}_{{.Arch}}" github.com/getlantern/flashlight