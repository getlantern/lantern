#!/usr/bin/env bash
set -euo pipefail

full_name="${INSTALLER_BASE_NAME}"
if [[ "$BUILD_TYPE" != "production" ]]; then
  full_name="${full_name}-${BUILD_TYPE}"
fi

current_dmg="${full_name}.dmg"
if [[ ! -f "$current_dmg" ]]; then
  echo "Current DMG not found: $current_dmg" >&2
  exit 1
fi

previous_dmg="$RUNNER_TEMP/previous-lantern.dmg"
previous_url="https://${BUCKET}.s3.amazonaws.com/releases/${BUILD_TYPE}/latest/${full_name}.dmg"

if ! curl -fLsS --retry 3 --retry-delay 2 -o "$previous_dmg" "$previous_url"; then
  echo "No previous DMG at $previous_url; skipping check."
  exit 0
fi

current_mount="$RUNNER_TEMP/current-dmg"
previous_mount="$RUNNER_TEMP/previous-dmg"
mkdir -p "$current_mount" "$previous_mount"

detach_if_mounted() {
  local mountpoint="$1"
  if mount | grep -Fq "on ${mountpoint} "; then
    hdiutil detach "$mountpoint" -quiet || true
  fi
}
trap 'detach_if_mounted "$current_mount"; detach_if_mounted "$previous_mount"' EXIT

hdiutil attach "$current_dmg" -mountpoint "$current_mount" -nobrowse -quiet
hdiutil attach "$previous_dmg" -mountpoint "$previous_mount" -nobrowse -quiet

find_plist() {
  find "$1" -path "*/SystemExtensions/org.getlantern.lantern.PacketTunnel.systemextension/Contents/Info.plist" -print -quit
}

current_plist="$(find_plist "$current_mount")"
previous_plist="$(find_plist "$previous_mount")"
if [[ -z "$current_plist" || -z "$previous_plist" ]]; then
  echo "Could not find system extension Info.plist in one of the DMGs." >&2
  exit 1
fi

current_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$current_plist")
previous_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$previous_plist")

echo "Previous sysext CFBundleVersion: $previous_build"
echo "Current sysext CFBundleVersion:  $current_build"

if [[ "$previous_build" =~ ^[0-9]+$ && "$current_build" =~ ^[0-9]+$ ]]; then
  if (( current_build <= previous_build )); then
    echo "Current sysext build number must be greater than previous latest." >&2
    exit 1
  fi
elif [[ "$current_build" == "$previous_build" ]]; then
  echo "Current sysext build number must change from previous latest." >&2
  exit 1
fi
