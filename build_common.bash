#!/bin/bash

# The VERSION is set to the tag for the current commit (if it exists) otherwise
# just the commit id.
export VERSION="`git describe --abbrev=0 --tags --exact-match || git rev-parse --short HEAD`"
export BUILD_DATE="`date -u +%Y%m%d%.%H%M%S`"
echo "Building flashlight version $VERSION ($BUILD_DATE)"
