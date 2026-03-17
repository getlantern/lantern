#!/usr/bin/env bash
set -euo pipefail

# Format release messages for various outputs
# Usage: format.sh <release-notes|job-summary|slack>
#
# Environment variables:
#   RELEASE_TAG:          release tag with 'v' prefix (e.g., v9.0.11, v9.0.11-beta, v9.0.11-abc123-20260207T044512Z)
#   INSTALLER_BASE_NAME:  installer base name WITHOUT build-type suffix (e.g., lantern-installer)
#   PLATFORM:             platforms built (all, or comma-separated)
#   BUCKET:               S3 bucket name
#   BUILD_TYPE:           production, beta, or nightly
#   GITHUB_REF_NAME:      branch/tag name (e.g., main, v9.0.11)
#   GITHUB_SHA:           commit SHA (required for release-notes)

FORMAT="${1:?Format required: release-notes, job-summary, or slack}"
RELEASE_TAG="${RELEASE_TAG:?RELEASE_TAG required}"
INSTALLER_BASE_NAME="${INSTALLER_BASE_NAME:?INSTALLER_BASE_NAME required}"
PLATFORM="${PLATFORM:?PLATFORM required}"
BUCKET="${BUCKET:?BUCKET required}"
BUILD_TYPE="${BUILD_TYPE:?BUILD_TYPE required}"
GITHUB_REF_NAME="${GITHUB_REF_NAME:?GITHUB_REF_NAME required}"

# Strip 'v' prefix for S3 paths and version display
VERSION="${RELEASE_TAG#v}"

# Construct full installer name with build type
FULL_INSTALLER_NAME="${INSTALLER_BASE_NAME}"
[[ -n "$BUILD_TYPE" && "$BUILD_TYPE" != "production" ]] && FULL_INSTALLER_NAME="${FULL_INSTALLER_NAME}-${BUILD_TYPE}"

VERSION_URL="https://${BUCKET}.s3.amazonaws.com/releases/${BUILD_TYPE}/${VERSION}"
LATEST_URL="https://${BUCKET}.s3.amazonaws.com/releases/${BUILD_TYPE}/latest"

# Check if a platform should be included
should_include() {
  local platform="$1"
  [[ "$PLATFORM" == "all" ]] || [[ "$PLATFORM" == *"$platform"* ]]
}

case "$FORMAT" in
release-notes)
  GITHUB_SHA="${GITHUB_SHA:?GITHUB_SHA required for release-notes}"
  COMMIT_SHORT="${GITHUB_SHA:0:7}"

  case "$BUILD_TYPE" in
  nightly)
    echo "This is an automated nightly build from commit \`${COMMIT_SHORT}\`."
    ;;
  beta)
    echo "This is a beta release from commit \`${COMMIT_SHORT}\`."
    ;;
  production)
    echo "This is a production release from commit \`${COMMIT_SHORT}\`."
    ;;
  esac

  echo ""
  echo "**Branch:** \`${GITHUB_REF_NAME}\`"
  echo ""

  if should_include "macos"; then
    echo "- [macOS (.dmg)](${LATEST_URL}/${FULL_INSTALLER_NAME}.dmg) ([permalink](${VERSION_URL}/${FULL_INSTALLER_NAME}.dmg))"
  fi

  if should_include "windows"; then
    echo "- [Windows (.exe)](${LATEST_URL}/${FULL_INSTALLER_NAME}.exe) ([permalink](${VERSION_URL}/${FULL_INSTALLER_NAME}.exe))"
  fi

  if should_include "android"; then
    echo "- [Android (.apk)](${LATEST_URL}/${FULL_INSTALLER_NAME}.apk) ([permalink](${VERSION_URL}/${FULL_INSTALLER_NAME}.apk))"
  fi

  if should_include "linux"; then
    echo "- [Linux (.deb)](${LATEST_URL}/${FULL_INSTALLER_NAME}.deb) ([permalink](${VERSION_URL}/${FULL_INSTALLER_NAME}.deb))"
    echo "- [Linux (.rpm)](${LATEST_URL}/${FULL_INSTALLER_NAME}.rpm) ([permalink](${VERSION_URL}/${FULL_INSTALLER_NAME}.rpm))"
  fi

  if should_include "ios" && [[ "$BUILD_TYPE" == "beta" || "$BUILD_TYPE" == "production" ]]; then
    echo "- iOS: Uploaded to TestFlight"
  fi
  ;;

job-summary)
  echo "## Lantern $VERSION"
  echo ""
  echo "**Release:** https://github.com/getlantern/lantern/releases/tag/$RELEASE_TAG"
  ;;

slack)
  text="Lantern $BUILD_TYPE <https://github.com/getlantern/lantern/releases/tag/$RELEASE_TAG|$RELEASE_TAG> is ready."
  text="${text}\n*Branch:* <https://github.com/getlantern/lantern/tree/$GITHUB_REF_NAME|$GITHUB_REF_NAME>"
  text="${text}\n*Downloads:*"

  if should_include "macos"; then
    text="${text}\n• macOS <${LATEST_URL}/${FULL_INSTALLER_NAME}.dmg|${FULL_INSTALLER_NAME}.dmg> (<${VERSION_URL}/${FULL_INSTALLER_NAME}.dmg|permalink>)"
  fi

  if should_include "windows"; then
    text="${text}\n• Windows <${LATEST_URL}/${FULL_INSTALLER_NAME}.exe|${FULL_INSTALLER_NAME}.exe> (<${VERSION_URL}/${FULL_INSTALLER_NAME}.exe|permalink>)"
  fi

  if should_include "android"; then
    text="${text}\n• Android <${LATEST_URL}/${FULL_INSTALLER_NAME}.apk|${FULL_INSTALLER_NAME}.apk> (<${VERSION_URL}/${FULL_INSTALLER_NAME}.apk|permalink>)"
  fi

  if should_include "linux"; then
    text="${text}\n• Linux <${LATEST_URL}/${FULL_INSTALLER_NAME}.deb|${FULL_INSTALLER_NAME}.deb> (<${VERSION_URL}/${FULL_INSTALLER_NAME}.deb|permalink>)"
    text="${text}\n• Linux <${LATEST_URL}/${FULL_INSTALLER_NAME}.rpm|${FULL_INSTALLER_NAME}.rpm> (<${VERSION_URL}/${FULL_INSTALLER_NAME}.rpm|permalink>)"
  fi

  if should_include "ios" && [[ "$BUILD_TYPE" == "beta" || "$BUILD_TYPE" == "production" ]]; then
    text="${text}\n• iOS: Build uploaded to TestFlight"
  fi

  echo "$text"
  ;;

*)
  echo "Error: Invalid format '$FORMAT'" >&2
  echo "Usage: format.sh <release-notes|job-summary|slack>" >&2
  exit 1
  ;;
esac
