#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

source setenv.bash

# Default Go compiler is the go command.
GO_BUILD="go build"

if which gox >/dev/null; then
  # If gox exists.
  GO_BUILD=gox
  GO_BUILD_WINDOWS='gox -osarch="windows/386"'
  GO_BUILD_DARWIN='gox -osarch="darwin/amd64"'
else
  GO_BUILD_WINDOWS=$GO_BUILD
  GO_BUILD_DARWIN=$GO_BUILD
fi

./genassets.bash || die "Could not generate assets"

# The VERSION is set to the tag for the current commit (if it exists) otherwise
# just the commit id.
VERSION="`git describe --abbrev=0 --tags --exact-match || git rev-parse --short HEAD`"
BUILD_DATE="`date -u +%Y%m%d.%H%M%S`"
export VERSION_STRING="$VERSION ($BUILD_DATE)"
LOGGLY_TOKEN="469973d5-6eaf-445a-be71-cf27141316a1"
LDFLAGS="-w -X main.version $VERSION -X main.buildDate $BUILD_DATE -X github.com/getlantern/flashlight/logging.logglyToken $LOGGLY_TOKEN"
echo "Building Lantern version $VERSION ($BUILD_DATE)"
# gox -ldflags="-w -X main.version $VERSION -X main.buildDate $BUILD_DATE -X main.logglyToken LOGGLY_TOKEN" -osarch="linux/386 linux/amd64 windows/386 darwin/amd64" github.com/getlantern/flashlight
# Compile for Mac

if [[ $OSTYPE == "darwin"* ]]; then
  echo "Building Lantern for OSX"
  CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 $GO_BUILD_DARWIN -tags="prod" -ldflags="$LDFLAGS" -o "lantern_darwin_amd64" github.com/getlantern/flashlight || die "Could not build OSX"
else
  echo "Building Lantern for OSX requires a darwin host. Skipping."
fi

echo "Build Lantern for Windows"
# Compile for Windows (use -H=windowsgui ldflag to make this a Windows instead of a console app)
CGO_ENABLED=1 GOOS=windows GOARCH=386 $GO_BUILD_WINDOWS -tags="prod" -ldflags="$LDFLAGS -H=windowsgui" -o "lantern_windows_386.exe" github.com/getlantern/flashlight || die "Could not build windows installer"

echo "******************************************"
echo "BUILD SUCCESSFUL FOR VERSION $VERSION!!"
echo "******************************************"
