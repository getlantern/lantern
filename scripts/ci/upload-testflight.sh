#!/usr/bin/env bash
# upload-testflight.sh — upload an IPA to App Store Connect, retrying Apple's
# transient delivery failures.
#
# Usage: upload-testflight.sh IPA
# Env:   APPSTORE_API_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_API_PRIVATE_KEY
#        UPLOAD_ATTEMPTS (default 4), UPLOAD_BACKOFF seconds (default 60)
#
# contentdelivery.itunes.apple.com regularly times out for several minutes at a
# time (NSURLError -1001/-1005, altool status -19235), so the wait before
# attempt N+1 is N*UPLOAD_BACKOFF. An attempt can deliver the build and still
# lose the final response; the retry then reports a redundant upload, which
# counts as success after the first attempt only.
set -uo pipefail

ipa=${1:?usage: $0 IPA}
: "${APPSTORE_API_KEY_ID:?}" "${APPSTORE_ISSUER_ID:?}" "${APPSTORE_API_PRIVATE_KEY:?}"
attempts=${UPLOAD_ATTEMPTS:-4}
backoff=${UPLOAD_BACKOFF:-60}

transient='NSURLErrorDomain Code=-10(01|05)|-19235|-19207|Try again later'
delivered='Redundant Binary Upload|ENTITY_ERROR\.ATTRIBUTE\.INVALID\.DUPLICATE'

# altool resolves --apiKey to ~/private_keys/AuthKey_<id>.p8.
key_file="$HOME/private_keys/AuthKey_${APPSTORE_API_KEY_ID}.p8"
mkdir -p "$(dirname "$key_file")"
(umask 077 && printf '%s\n' "$APPSTORE_API_PRIVATE_KEY" > "$key_file")
log=$(mktemp)
trap 'rm -f "$key_file" "$log"' EXIT

attempt=1
while :; do
  xcrun altool --output-format xml --upload-app --file "$ipa" --type ios \
    --apiKey "$APPSTORE_API_KEY_ID" --apiIssuer "$APPSTORE_ISSUER_ID" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] && exit 0

  if [ "$attempt" -gt 1 ] && grep -qE -- "$delivered" "$log"; then
    echo "An earlier attempt delivered $ipa; treating the redundant upload as success" >&2
    exit 0
  fi
  if ! grep -qE -- "$transient" "$log"; then
    exit "$status"
  fi
  if [ "$attempt" -ge "$attempts" ]; then
    echo "altool: giving up after $attempt attempts (exit $status)" >&2
    exit "$status"
  fi
  delay=$((attempt * backoff))
  echo "altool: transient App Store Connect failure on attempt $attempt/$attempts (exit $status); retrying in ${delay}s" >&2
  sleep "$delay"
  attempt=$((attempt + 1))
done
