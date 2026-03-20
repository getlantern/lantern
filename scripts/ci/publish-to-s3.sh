#!/usr/bin/env bash

set -euo pipefail

# Upload build artifacts to S3
# Usage: publish-to-s3.sh <build_type> <version> <installer_base_name> <platforms>
#
# Arguments:
#   build_type:          production, beta, or nightly
#   version:             version string (e.g., 1.2.3 or 1.2.4-abc123-20260206T120000Z) - no 'v' prefix
#   installer_base_name: base name WITHOUT build-type suffix (e.g., lantern-installer)
#                        Script appends -$BUILD_TYPE for non-production builds
#   platforms:           comma-separated list or "all" (e.g., "macos,linux" or "all")
#
# Environment variables:
#   BUCKET:                  S3 bucket name (required)
#   AWS_ACCESS_KEY_ID:       AWS credentials (required)
#   AWS_SECRET_ACCESS_KEY:   AWS credentials (required)

BUILD_TYPE="${1:?Build type required}"
VERSION="${2:?Version required}"
INSTALLER_BASE_NAME="${3:?Installer base name required}"
PLATFORMS="${4:?Platforms required}"

BUCKET="${BUCKET:?BUCKET environment variable required}"

# All builds use the same path structure: releases/{build_type}/{version}/
VERSION_PREFIX="releases/${BUILD_TYPE}/${VERSION}"
LATEST_PREFIX="releases/${BUILD_TYPE}/latest"

echo "Publishing artifacts to S3:"
echo "  Build type:    $BUILD_TYPE"
echo "  Version:       $VERSION"
echo "  Installer:     $INSTALLER_BASE_NAME"
echo "  Platforms:     $PLATFORMS"
echo "  Bucket:        $BUCKET"
echo "  Version path:  $VERSION_PREFIX"
echo "  Latest path:   $LATEST_PREFIX"
echo ""

# Check if a platform should be uploaded based on the platforms list
should_upload() {
  local platform="$1"
  [[ "$PLATFORMS" == "all" ]] || [[ "$PLATFORMS" == *"$platform"* ]]
}

# Upload a single artifact if it exists
# Returns: 0=success, 1=not found, 2=upload failed
upload_artifact() {
  local platform="$1"
  local extension="$2"
  local artifact_dir="lantern-installer-${extension}"
  # Construct full filename with build type (Makefile appends it)
  local filename="${INSTALLER_BASE_NAME}"
  [[ -n "$BUILD_TYPE" && "$BUILD_TYPE" != "production" ]] && filename="${filename}-${BUILD_TYPE}"
  filename="${filename}.${extension}"
  local filepath="${artifact_dir}/${filename}"

  if [[ ! -f "$filepath" ]]; then
    echo "⊘ Skipping $platform ($filename not found)"
    return 1
  fi

  echo "↑ Uploading $platform: $filename"

  # Upload to versioned path
  if ! aws s3 cp "$filepath" "s3://${BUCKET}/${VERSION_PREFIX}/${filename}" --acl public-read; then
    echo "✗ Failed to upload $filename to versioned path" >&2
    return 2
  fi

  # Upload to latest alias
  if ! aws s3 cp "$filepath" "s3://${BUCKET}/${LATEST_PREFIX}/${filename}" --acl public-read; then
    echo "✗ Failed to upload $filename to latest path" >&2
    return 2
  fi

  echo "✓ Uploaded $platform successfully"
  echo "  - https://${BUCKET}.s3.amazonaws.com/${VERSION_PREFIX}/${filename}"
  echo "  - https://${BUCKET}.s3.amazonaws.com/${LATEST_PREFIX}/${filename}"
  return 0
}

# platform:extension
declare -a artifacts=(
  "macos:dmg"
  "windows:exe"
  "android:apk"
  "linux:deb"
  "linux:rpm"
  "ios:ipa"
)

uploaded=0
skipped=0
failed=0

for artifact in "${artifacts[@]}"; do
  platform="${artifact%%:*}"
  extension="${artifact##*:}"

  if ! should_upload "$platform"; then
    continue
  fi

  upload_artifact "$platform" "$extension"
  result=$?

  case $result in
  0) uploaded=$((uploaded + 1)) ;;
  1) skipped=$((skipped + 1)) ;;
  2) failed=$((failed + 1)) ;;
  esac
done

echo ""
echo "Upload summary: $uploaded uploaded, $skipped skipped, $failed failed"

if [[ $failed -gt 0 ]]; then
  echo "✗ $failed artifact(s) failed to upload" >&2
  exit 1
fi

if [[ $uploaded -eq 0 ]]; then
  echo "✗ No artifacts were uploaded" >&2
  exit 1
fi

echo "✓ All uploads successful"
exit 0
