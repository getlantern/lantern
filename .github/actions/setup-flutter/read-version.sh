#!/usr/bin/env bash
# Deliberately accept only the repository's single pinned-version format.
set -euo pipefail

if [[ $(grep -c '^[[:space:]]*flutter:' "$1") -ne 1 ]]; then
  echo "Expected exactly one pinned Flutter version in $1" >&2
  exit 1
fi
version=$(sed -n 's/^[[:space:]]*flutter:[[:space:]]*//p' "$1" | sed -E 's/[[:space:]]+$//; s/^"([^"]*)"$/\1/')
if ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$'; then
  echo "Invalid pinned Flutter version: $version" >&2
  exit 1
fi
printf '%s\n' "$version"
