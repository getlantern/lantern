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
#   LINUX_ARCH:              amd64, arm64, or all (optional, defaults to all)

BUILD_TYPE="${1:?Build type required}"
VERSION="${2:?Version required}"
INSTALLER_BASE_NAME="${3:?Installer base name required}"
PLATFORMS="${4:?Platforms required}"

BUCKET="${BUCKET:?BUCKET environment variable required}"
LINUX_ARCH="${LINUX_ARCH:-all}"

case "$LINUX_ARCH" in
  amd64|arm64|all)
    ;;
  *)
    echo "✗ Invalid LINUX_ARCH value: '$LINUX_ARCH'. Expected 'amd64', 'arm64', or 'all'." >&2
    exit 1
    ;;
esac
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

should_upload() {
  local platform="$1"
  [[ "$PLATFORMS" == "all" || ",$PLATFORMS," == *",$platform,"* ]]
}

upload_file() {
  local filepath="$1"
  local filename
  filename="$(basename "$filepath")"
  local checksum
  checksum="$(sha256sum "$filepath" | awk '{print $1}')"
  echo "↑ Uploading $filename"
  aws s3 cp "$filepath" "s3://${BUCKET}/${VERSION_PREFIX}/${filename}" \
    --acl public-read --metadata "sha256=${checksum}"

  # Stable and beta aliases move only after the GitHub release is verified.
  if [[ "$BUILD_TYPE" == "nightly" ]]; then
    aws s3 cp "$filepath" "s3://${BUCKET}/${LATEST_PREFIX}/${filename}" \
      --acl public-read --metadata "sha256=${checksum}"
  fi

  echo "✓ Uploaded $filename"
  echo "  - https://s3.amazonaws.com/${BUCKET}/${VERSION_PREFIX}/${filename}"
  if [[ "$BUILD_TYPE" == "nightly" ]]; then
    echo "  - https://s3.amazonaws.com/${BUCKET}/${LATEST_PREFIX}/${filename}"
  fi
}

artifact_path() {
  local platform="$1"
  local extension="$2"
  local arch="${3:-}"

  local base_name="${INSTALLER_BASE_NAME}"
  [[ -n "$BUILD_TYPE" && "$BUILD_TYPE" != "production" ]] && base_name="${base_name}-${BUILD_TYPE}"

  # Map compound extensions to short artifact directory names
  local dir_ext="$extension"
  case "$extension" in
    pkg.tar.zst) dir_ext="pkg" ;;
  esac

  local filename
  local -a candidate_dirs=()
  if [[ "$arch" == "arm64" ]]; then
    filename="${base_name}-arm64.${extension}"
    candidate_dirs=("lantern-installer-${dir_ext}-arm64")
  elif [[ "$arch" == "amd64" ]]; then
    filename="${base_name}.${extension}"
    candidate_dirs=("lantern-installer-${dir_ext}-amd64" "lantern-installer-${dir_ext}")
  else
    filename="${base_name}.${extension}"
    candidate_dirs=("lantern-installer-${dir_ext}")
  fi

  local dir candidate
  for dir in "${candidate_dirs[@]}"; do
    candidate="${dir}/${filename}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "Required $platform release artifact is missing: $filename" >&2
  return 1
}

# platform:extension:arch(optional)
declare -a artifacts=(
  "macos:dmg:"
  "windows:exe:"
  "android:apk:"
  "ios:ipa:"
)

if [[ "$LINUX_ARCH" == "all" || "$LINUX_ARCH" == "amd64" ]]; then
  artifacts+=("linux:deb:amd64" "linux:rpm:amd64" "linux:pkg.tar.zst:amd64")
fi
if [[ "$LINUX_ARCH" == "all" || "$LINUX_ARCH" == "arm64" ]]; then
  artifacts+=("linux:deb:arm64" "linux:rpm:arm64" "linux:pkg.tar.zst:arm64")
fi

# Check the whole candidate set before uploading anything, including nightly aliases.
files=()
for artifact in "${artifacts[@]}"; do
  IFS=':' read -r platform extension arch <<<"$artifact"

  if ! should_upload "$platform"; then
    continue
  fi

  files+=("$(artifact_path "$platform" "$extension" "$arch")")
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No release artifacts selected for: $PLATFORMS" >&2
  exit 1
fi

for file in "${files[@]}"; do
  upload_file "$file"
done

echo "✓ Uploaded ${#files[@]} artifacts"
