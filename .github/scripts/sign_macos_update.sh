#!/usr/bin/env bash
set -euo pipefail

installer_path="${1:-}"
signature_path="${2:-}"
signer_path="${3:-macos/Pods/Sparkle/bin/sign_update}"

if [[ -z "$installer_path" || -z "$signature_path" ]]; then
  printf 'Usage: %s <installer-path> <signature-path> [sign-update-path]\n' "$0" >&2
  exit 2
fi
if [[ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  printf 'SPARKLE_ED_PRIVATE_KEY is required for macOS update signing\n' >&2
  exit 1
fi
if [[ ! -f "$installer_path" ]]; then
  printf 'macOS installer not found: %s\n' "$installer_path" >&2
  exit 1
fi
if [[ ! -x "$signer_path" ]]; then
  printf 'Sparkle signer not found or not executable: %s\n' "$signer_path" >&2
  exit 1
fi

mkdir -p "$(dirname "$signature_path")"
temporary_signature="$(mktemp "${signature_path}.tmp.XXXXXX")"
trap 'rm -f "$temporary_signature"' EXIT

signature="$({
  printf '%s' "$SPARKLE_ED_PRIVATE_KEY" \
    | "$signer_path" --ed-key-file - -p "$installer_path"
} | tr -d '\r\n')"
if [[ -z "$signature" ]]; then
  printf 'Sparkle produced an empty macOS update signature\n' >&2
  exit 1
fi

printf '%s' "$SPARKLE_ED_PRIVATE_KEY" \
  | "$signer_path" --verify --ed-key-file - "$installer_path" "$signature"

printf '%s\n' "$signature" >"$temporary_signature"
mv "$temporary_signature" "$signature_path"
trap - EXIT
