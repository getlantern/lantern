#!/usr/bin/env bash
set -euo pipefail

# Version management script
#
# Usage:
#   version.sh validate <version>    - Validate release format and ordering
#   version.sh generate <build-type> - Generate next version (nightly|beta)
#   version.sh extract <version>     - Extract base semver (strips suffixes)
#
# All commands work with version strings (no 'v' prefix), but accept 'v' and strip it.
#
# Examples:
#   version.sh validate v1.2.3          → 1.2.3
#   version.sh validate v1.2.3-beta.1   → 1.2.3-beta.1
#   version.sh generate beta            → 1.2.3-beta.2 (after beta.1)
#   version.sh generate nightly         → 1.2.4-abc123-20260206T120000Z
#   version.sh extract 1.2.3-beta.1     → 1.2.3

COMMAND="${1:?Command required: validate, generate, or extract}"
shift

NUMBER='(0|[1-9][0-9]*)'
BASE_PATTERN="${NUMBER}\.${NUMBER}\.${NUMBER}"
PLATFORM_PATTERN='(windows|macos|linux|android|ios)'

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
  [[ "$1" =~ ^${BASE_PATTERN}$ ]]
}

strip_platform() {
  case "$1" in
    *-windows|*-macos|*-linux|*-android|*-ios) echo "${1%-*}" ;;
    *) echo "$1" ;;
  esac
}

# Return application versions, without the tag prefix or platform selector.
# Historical beta spellings remain discoverable but cannot be newly released.
release_versions() {
  local type="$1"
  local pattern tag version
  case "$type" in
  production)
    pattern="^${BASE_PATTERN}(-${PLATFORM_PATTERN})?$"
    ;;
  beta)
    pattern="^${BASE_PATTERN}-beta(\.${NUMBER}|-?[0-9]+)?(-${PLATFORM_PATTERN})?$"
    ;;
  canonical-beta)
    pattern="^${BASE_PATTERN}-beta\.${NUMBER}(-${PLATFORM_PATTERN})?$"
    ;;
  legacy-beta)
    pattern="^${BASE_PATTERN}-beta(-?[0-9]+)?(-${PLATFORM_PATTERN})?$"
    ;;
  *)
    echo "Error: Unknown type '$type'" >&2
    return 1
    ;;
  esac

  git tag -l 'v[0-9]*' | while IFS= read -r tag; do
    version="${tag#v}"
    if [[ "$version" =~ $pattern ]]; then
      strip_platform "$version"
    fi
  done
}

get_latest_version() {
  release_versions "$1" \
    | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*$/\1/' \
    | sort -V | tail -1
}

get_latest_beta_number() {
  local base="$1" version
  release_versions canonical-beta | while IFS= read -r version; do
    if [[ "${version%-beta.*}" == "$base" ]]; then
      echo "${version##*.}"
    fi
  done | sort -V | tail -1
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

  RELEASE_PATTERN="^${BASE_PATTERN}(-beta\.${NUMBER})?(-${PLATFORM_PATTERN})?$"
  if [[ ! "$VERSION" =~ $RELEASE_PATTERN ]]; then
    echo "Error: Version '$INPUT' is not a valid release version" >&2
    echo "Error: Use X.Y.Z or X.Y.Z-beta.N, optionally followed by -<platform>" >&2
    echo "Error: Beta numbers must be dot-separated with no leading zeros (e.g., v1.2.3-beta.1)" >&2
    exit 1
  fi

  PROD=$(get_latest_version production)
  BETA=$(get_latest_version beta)

  RELEASE_VERSION=$(strip_platform "$VERSION")
  if [[ "$RELEASE_VERSION" == *-beta.* ]]; then
    LEGACY=$(get_latest_version legacy-beta)
    # Existing clients see stable X.Y.Z and legacy beta-N/betaN as newer
    # than X.Y.Z-beta.N. Migration must therefore use a higher base.
    if [[ "$BASE" == "$PROD" || "$BASE" == "$LEGACY" ]]; then
      echo "Error: Beta '$INPUT' needs a higher base than the existing stable or legacy beta release '$BASE'" >&2
      exit 1
    fi
    BETA_NUMBER="${RELEASE_VERSION##*.}"
    LATEST_NUMBER=$(get_latest_beta_number "$BASE")
    # Equality is intentional: CI validates the current tag after fetching it,
    # and multiple platform tags can share the same application version.
    if [[ -n "$LATEST_NUMBER" && "$BETA_NUMBER" != "$LATEST_NUMBER" ]] \
      && [[ "$(max_semver "$BETA_NUMBER" "$LATEST_NUMBER")" == "$LATEST_NUMBER" ]]; then
      echo "Error: Beta '$INPUT' would go backwards from '$BASE-beta.$LATEST_NUMBER'" >&2
      exit 1
    fi
  fi

  # Get highest base version across all types
  HIGHEST="0.0.0"
  [[ -n "$PROD" ]] && HIGHEST=$(max_semver "$HIGHEST" "$PROD")
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
  BUILD_TYPE="${1:?Build type required: nightly or beta}"

  case "$BUILD_TYPE" in
  nightly)
    PROD=$(get_latest_version production)
    BETA=$(get_latest_version beta)

    if [[ -z "$PROD" && -z "$BETA" ]]; then
      echo "Error: No production or beta tags found" >&2
      echo "Error: Create an initial tag (e.g., v1.0.0)" >&2
      exit 1
    fi

    BASELINE=$(max_semver "${PROD:-0.0.0}" "${BETA:-0.0.0}")
    NEXT=$(increment_patch "$BASELINE")
    SHA=$(git rev-parse --short=7 HEAD)
    TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

    echo "${NEXT}-${SHA}-${TIMESTAMP}"
    ;;

  beta)
    BETA=$(get_latest_version beta)
    PROD=$(get_latest_version production)

    if [[ -z "$BETA" && -z "$PROD" ]]; then
      echo "Error: No tags found" >&2
      exit 1
    fi

    BASELINE=$(max_semver "${BETA:-0.0.0}" "${PROD:-0.0.0}")
    LEGACY=$(get_latest_version legacy-beta)
    LATEST_NUMBER=$(get_latest_beta_number "$BASELINE")
    if [[ -n "$LATEST_NUMBER" && "$BASELINE" != "$PROD" && "$BASELINE" != "$LEGACY" ]]; then
      NEXT_NUMBER=$(increment_patch "$LATEST_NUMBER")
      echo "${BASELINE}-beta.${NEXT_NUMBER}"
    else
      NEXT=$(increment_patch "$BASELINE")
      echo "${NEXT}-beta.1"
    fi
    ;;

  *)
    echo "Error: Invalid build type '$BUILD_TYPE'" >&2
    echo "Usage: version.sh generate <nightly|beta>" >&2
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
