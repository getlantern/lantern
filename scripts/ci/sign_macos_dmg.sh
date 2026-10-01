#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'Usage: %s APP_PATH DMG_PATH\n' "$0" >&2
  exit 2
fi

app_path="$1"
dmg_path="$2"
[[ -d "$app_path" && -f "$dmg_path" ]] || {
  printf 'The signed app and packaged DMG must both exist.\n' >&2
  exit 1
}

certificate_dir="$(mktemp -d)"
trap 'rm -rf "$certificate_dir"' EXIT

# Reuse the app's certificate; several signing identities can share a name.
codesign --display --extract-certificates="$certificate_dir/cert" "$app_path"
sign_id="$(openssl x509 -inform DER -in "$certificate_dir/cert0" \
  -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
[[ "$sign_id" =~ ^[0-9A-Fa-f]{40}$ ]] || {
  printf 'Could not read the app signing certificate fingerprint.\n' >&2
  exit 1
}

codesign --force --sign "$sign_id" --timestamp \
  --identifier org.getlantern.lantern.diskimage "$dmg_path"
codesign --verify --strict --verbose=2 "$dmg_path"
