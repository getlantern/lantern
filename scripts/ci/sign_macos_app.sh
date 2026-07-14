#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 APP_PATH SIGN_ID APP_ENTITLEMENTS PACKET_ENTITLEMENTS" >&2
  exit 2
fi

app_path="$1"
sign_id="$2"
app_entitlements="$3"
packet_entitlements="$4"
frameworks_dir="$app_path/Contents/Frameworks"
system_extension="$app_path/Contents/Library/SystemExtensions/org.getlantern.lantern.PacketTunnel.systemextension"

sign_code() {
  local target="$1"
  shift

  [[ -e "$target" ]] || return 0
  codesign \
    --options runtime \
    --strict \
    --timestamp \
    --force \
    "$@" \
    --sign "$sign_id" \
    --verbose \
    "$target"
}

# Sparkle's helpers must be signed before the framework that contains them.
sparkle_framework="$frameworks_dir/Sparkle.framework"
if [[ -d "$sparkle_framework" ]]; then
  sparkle_version="$sparkle_framework/Versions/Current"
  sign_code "$sparkle_version/XPCServices/Installer.xpc"
  sign_code "$sparkle_version/XPCServices/Downloader.xpc" \
    --preserve-metadata=entitlements
  sign_code "$sparkle_version/Autoupdate"
  sign_code "$sparkle_version/Updater.app"
  sign_code "$sparkle_framework"
fi

while IFS= read -r -d '' code; do
  sign_code "$code"
done < <(
  find "$frameworks_dir" -maxdepth 1 \
    \( -type d -name '*.framework' ! -name 'Sparkle.framework' \
       -o -type f -name '*.dylib' \) \
    -print0
)

sign_code "$system_extension/Contents/Frameworks/Liblantern.framework"
sign_code "$system_extension" --entitlements "$packet_entitlements"
sign_code "$app_path" --entitlements "$app_entitlements"

codesign --verify --deep --strict --verbose=2 "$app_path"
