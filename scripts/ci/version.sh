#!/usr/bin/env bash
set -euo pipefail

# Version management script
#
# Usage:
#   version.sh validate <version>    - Validate fails on semver violations
#   version.sh generate <build-type> - Generate next version (nightly|internal|beta)
#   version.sh extract <version>     - Extract base semver (strips suffixes)
#
# All commands work with version strings (no 'v' prefix), but accept 'v' and strip it.
#
# Examples:
#   version.sh validate v1.2.3          → 1.2.3
#   version.sh validate v1.2.3-beta     → 1.2.3-beta
#   version.sh generate nightly         → 1.2.4-abc123-20260206T120000Z
#   version.sh generate internal        → 1.2.4-internal
#   version.sh extract 1.2.3-beta       → 1.2.3

COMMAND="${1:?Command required: validate, generate, or extract}"
shift

# strip v prefix, keep suffix
strip_v() {
  echo "$1" | sed -E 's/^v//'
}

# extract base semver from version string (strips v prefix and suffixes)
extract_basever() {
  echo "$1" | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*$/\1/'
}

# format "X.Y.Z", no v or suffixes
validate_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

get_latest_version() {
  local type="$1"
  local pattern

  case "$type" in
  production)
    # Match v9.0.11, v9.0.11-macos, etc. (but not v9.0.11-beta or v9.0.11-internal)
    local tag=$(git tag -l 'v[0-9]*\.[0-9]*\.[0-9]*' 'v[0-9]*\.[0-9]*\.[0-9]*-*' | grep -v -E -- '-(beta|internal)|T.*Z' | sort -V | tail -1)
    ;;
  internal)
    # Match v9.0.11-internal, v9.0.11-internal-linux, etc. (but not nightly with timestamps)
    local tag=$(git tag -l 'v[0-9]*\.[0-9]*\.[0-9]*-internal' 'v[0-9]*\.[0-9]*\.[0-9]*-internal-*' | grep -v -E -- 'T.*Z' | sort -V | tail -1)
    ;;
  beta)
    # Match v9.0.11-beta, v9.0.11-beta-macos, etc. (but not nightly with timestamps)
    local tag=$(git tag -l 'v[0-9]*\.[0-9]*\.[0-9]*-beta' 'v[0-9]*\.[0-9]*\.[0-9]*-beta-*' | grep -v -E -- 'T.*Z' | sort -V | tail -1)
    ;;
  *)
    echo "Error: Unknown type '$type'" >&2
    return 1
    ;;
  esac

  [[ -n "$tag" ]] && extract_basever "$tag"
}

increment_patch() {
  echo "$1" | awk -F'.' -v OFS='.' '{ $NF = $NF + 1; print }'
}

max_semver() {
  printf "%s\n%s\n" "$1" "$2" | sort -V | tail -1
}

case "$COMMAND" in
validate)
  INPUT="${1:?Version required}"
  VERSION=$(strip_v "$INPUT")
  BASE=$(extract_basever "$VERSION")

  if ! validate_semver "$BASE"; then
    echo "Error: Version '$INPUT' is not valid semver" >&2
    echo "Error: Expected format: X.Y.Z (e.g., 1.2.3, v1.2.3-beta)" >&2
    exit 1
  fi

  # Get highest base version across all types
  PROD=$(get_latest_version production)
  INTERNAL=$(get_latest_version internal)
  BETA=$(get_latest_version beta)

  HIGHEST="0.0.0"
  [[ -n "$PROD" ]] && HIGHEST=$(max_semver "$HIGHEST" "$PROD")
  [[ -n "$INTERNAL" ]] && HIGHEST=$(max_semver "$HIGHEST" "$INTERNAL")
  [[ -n "$BETA" ]] && HIGHEST=$(max_semver "$HIGHEST" "$BETA")

  # Validate new version is >= highest
  if [[ "$HIGHEST" != "0.0.0" ]]; then
    HIGHER=$(max_semver "$BASE" "$HIGHEST")

    if [[ "$HIGHER" == "$HIGHEST" && "$BASE" != "$HIGHEST" ]]; then
      echo "Error: Version '$BASE' is less than highest existing version '$HIGHEST'" >&2
      echo "Error: Version '$INPUT' would go backwards" >&2
      exit 1
    fi
  fi

  echo "$VERSION"
  ;;

generate)
  BUILD_TYPE="${1:?Build type required: nightly, internal, or beta}"

  case "$BUILD_TYPE" in
  nightly)
    PROD=$(get_latest_version production)
    INTERNAL=$(get_latest_version internal)

    if [[ -z "$PROD" && -z "$INTERNAL" ]]; then
      echo "Error: No production or internal tags found" >&2
      echo "Error: Create an initial tag (e.g., v1.0.0)" >&2
      exit 1
    fi

    BASELINE=$(max_semver "${PROD:-0.0.0}" "${INTERNAL:-0.0.0}")
    NEXT=$(increment_patch "$BASELINE")
    SHA=$(git rev-parse --short=7 HEAD)
    TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

    echo "${NEXT}-${SHA}-${TIMESTAMP}"
    ;;

  internal)
    INTERNAL=$(get_latest_version internal)

    if [[ -n "$INTERNAL" ]]; then
      BASELINE="$INTERNAL"
    else
      PROD=$(get_latest_version production)
      if [[ -z "$PROD" ]]; then
        echo "Error: No production or internal tags found" >&2
        exit 1
      fi
      BASELINE="$PROD"
    fi

    NEXT=$(increment_patch "$BASELINE")
    echo "${NEXT}-internal"
    ;;

  beta)
    INTERNAL=$(get_latest_version internal)
    BETA=$(get_latest_version beta)

    if [[ -z "$INTERNAL" && -z "$BETA" ]]; then
      PROD=$(get_latest_version production)
      if [[ -z "$PROD" ]]; then
        echo "Error: No tags found" >&2
        exit 1
      fi
      BASELINE="$PROD"
    else
      BASELINE=$(max_semver "${INTERNAL:-0.0.0}" "${BETA:-0.0.0}")
    fi

    NEXT=$(increment_patch "$BASELINE")
    echo "${NEXT}-beta"
    ;;

  *)
    echo "Error: Invalid build type '$BUILD_TYPE'" >&2
    echo "Usage: version.sh generate <nightly|internal|beta>" >&2
    exit 1
    ;;
  esac
  ;;

extract)
  VERSION="${1:?Version required}"
  BASE=$(extract_basever "$VERSION")

  if ! validate_semver "$BASE"; then
    echo "Error: Version '$VERSION' does not contain valid semver" >&2
    exit 1
  fi

  echo "$BASE"
  ;;

*)
  echo "Error: Invalid command '$COMMAND'" >&2
  echo "Usage: version.sh <validate|generate|extract> [args]" >&2
  exit 1
  ;;
esac
