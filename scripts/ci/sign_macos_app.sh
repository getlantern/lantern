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

app_bundle_id="org.getlantern.lantern"
tunnel_bundle_id="org.getlantern.lantern.PacketTunnel"

# ── Signing identity resolution ──────────────────────────────────────────────
# Several Developer ID Application certs routinely share the identical display
# name "Developer ID Application: <org> (<TEAM>)". Passing that name to codesign
# is therefore a request for "whichever the keychain lists first", and adding an
# unrelated cert silently changes which one a build picks — a build that worked
# yesterday failing today for a reason nowhere in the diff. codesign itself
# refuses with "ambiguous (matches ... and ...)".
#
# The provisioning profiles are the authority: each embeds the exact set of
# certs it accepts. Intersecting that with the certs the keychain can actually
# sign with normally yields a unique answer, with no guessing.
#
# This matters beyond convenience. Signing with a cert the profile does not
# embed produces a build that notarizes successfully and then refuses to launch
# (AMFI spawn error 163) — a failure that surfaces long after the build.

# Every cert SHA-1 (upper-case, no colons) embedded in provisioning profile $1.
profile_certs() {
  local plist cert i=0
  plist="$(security cms -D -i "$1" 2>/dev/null)" || return 0
  while cert="$(printf '%s' "$plist" | plutil -extract "DeveloperCertificates.$i" raw -o - - 2>/dev/null \
      | base64 -d 2>/dev/null | openssl x509 -inform DER -noout -fingerprint -sha1 2>/dev/null \
      | sed 's/.*=//; s/://g' | tr '[:lower:]' '[:upper:]')" && [[ -n "$cert" ]]; do
    echo "$cert"
    i=$((i + 1))
  done
}

# Profiles whose entitlements name app-id $1 exactly. Both search paths matter:
# Xcode writes to UserData, while CI installs into the older MobileDevice path.
# The trailing quote keeps `...lantern` from also matching `...lantern.PacketTunnel`.
profiles_for_appid() {
  local dir file
  for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
             "$HOME/Library/MobileDevice/Provisioning Profiles"; do
    [[ -d "$dir" ]] || continue
    for file in "$dir"/*.provisionprofile; do
      [[ -f "$file" ]] || continue
      security cms -D -i "$file" 2>/dev/null | plutil -p - 2>/dev/null \
        | grep -qF ".$1\"" && echo "$file"
    done
  done
  return 0
}

# SHA-1s of the codesigning identities matching $1 that hold a private key.
# `find-identity -v` lists only usable identities.
# `|| true`: no match is a normal answer here, but grep exits 1 and would abort
# the script under `set -e`/`pipefail` before the diagnostics below could run.
keychain_identities() {
  security find-identity -v -p codesigning 2>/dev/null \
    | { grep -F "$1" || true; } | awk '{print $2}'
}

describe_profile() {
  local plist name
  plist="$(security cms -D -i "$1" 2>/dev/null)" || return 0
  name="$(printf '%s' "$plist" | plutil -extract Name raw -o - - 2>/dev/null)"
  printf '         %s "%s" accepts: %s\n' \
    "$(basename "$1")" "$name" "$(profile_certs "$1" | tr '\n' ' ')" >&2
}

# Prefer a cert both the app and the system-extension profiles accept: the
# extension is signed first, so a mismatch there would otherwise surface only
# after the app had already been signed.
derive_sign_identity() {
  local app_certs tunnel_certs cert both="" any=""
  app_certs="$(while read -r p; do [[ -n "$p" ]] && profile_certs "$p"; done \
    < <(profiles_for_appid "$app_bundle_id") | sort -u)"
  tunnel_certs="$(while read -r p; do [[ -n "$p" ]] && profile_certs "$p"; done \
    < <(profiles_for_appid "$tunnel_bundle_id") | sort -u)"
  [[ -n "$app_certs" ]] || return 1
  while read -r cert; do
    [[ -n "$cert" ]] || continue
    grep -qx "$cert" <<<"$app_certs" || continue
    any="${any:-$cert}"
    if [[ -n "$tunnel_certs" ]] && grep -qx "$cert" <<<"$tunnel_certs"; then
      both="${both:-$cert}"
    fi
  done < <(keychain_identities "$sign_id")
  [[ -n "${both:-$any}" ]] || return 1
  echo "${both:-$any}"
}

# A caller-supplied SHA-1 is already unambiguous; honour it untouched.
if [[ ! "$sign_id" =~ ^[0-9A-Fa-f]{40}$ ]]; then
  matches="$(keychain_identities "$sign_id" | wc -l | tr -d ' ')"
  if [[ "$matches" -eq 0 ]]; then
    echo "ERROR: no codesigning identity in this keychain matches \"$sign_id\"." >&2
    exit 1
  elif [[ "$matches" -gt 1 ]]; then
    # Only resolve when the name is genuinely ambiguous, so the common
    # single-cert case keeps working exactly as before.
    if derived="$(derive_sign_identity)" && [[ -n "$derived" ]]; then
      echo "note: \"$sign_id\" matches $matches identities; using $derived, the cert the" >&2
      echo "      provisioning profiles accept." >&2
      sign_id="$derived"
    else
      echo "ERROR: \"$sign_id\" matches $matches identities in this keychain, and none of" >&2
      echo "       them is accepted by a provisioning profile for $app_bundle_id." >&2
      echo "       Signing with a cert the profile does not embed notarizes and then fails" >&2
      echo "       to launch (AMFI spawn error 163). Pass a SHA-1 as SIGN_ID to override." >&2
      echo "       keychain can sign with: $(keychain_identities "$sign_id" | tr '\n' ' ')" >&2
      while read -r p; do [[ -n "$p" ]] && describe_profile "$p"; done \
        < <(profiles_for_appid "$app_bundle_id"; profiles_for_appid "$tunnel_bundle_id")
      exit 1
    fi
  fi
fi

require_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'required signing input not found: %s\n' "$path" >&2
    exit 1
  fi
}

sign_code() {
  local target="$1"
  shift

  require_path "$target"
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

require_path "$app_path"
require_path "$app_entitlements"
require_path "$packet_entitlements"
require_path "$frameworks_dir"
require_path "$system_extension"
require_path "$system_extension/Contents/Frameworks/Liblantern.framework"

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
