#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 )) || [[ -z "$1" ]]; then
  echo "Usage: $0 EXPECTED_VERSION APK [APK ...] (EXPECTED_VERSION must not be empty)" >&2
  exit 2
fi

expected_version=$1
shift

if ! command -v apkanalyzer >/dev/null 2>&1; then
  echo "Android version verification failed: apkanalyzer is not on PATH" >&2
  exit 1
fi

for apk in "$@"; do
  if ! actual_version=$(apkanalyzer manifest version-name "$apk"); then
    echo "Android version verification failed: could not read versionName from $apk" >&2
    exit 1
  fi
  if [[ -z "$actual_version" ]]; then
    echo "Android version verification failed: $apk has an empty versionName" >&2
    exit 1
  fi
  if [[ "$actual_version" != "$expected_version" ]]; then
    echo "Android version verification failed: $apk has versionName '$actual_version'; expected '$expected_version'" >&2
    exit 1
  fi
  printf 'Verified %s versionName=%s\n' "$apk" "$actual_version"
done
