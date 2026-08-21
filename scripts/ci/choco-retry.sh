#!/usr/bin/env bash
# choco-retry.sh — `choco install` with retries and backoff.
#
# community.chocolatey.org 504s intermittently, and a single gateway timeout
# has failed two consecutive Windows release builds (v9.1.18-beta 2026-07-26:
# mingw + yq; v9.1.19-beta 2026-08-05: yq). A transient feed error should cost
# a retry, not the build.
#
# --ignore-package-exit-codes: MSI success-with-reboot codes (1641/3010) would
# otherwise surface as nonzero — and 8-bit-truncated by bash on Windows, so
# unmatchable by value — and read as failures. With the flag, choco exits 0
# unless it itself detected a failure.
set -u

for attempt in 1 2 3 4 5; do
  if choco install "$@" --ignore-package-exit-codes; then
    exit 0
  fi
  if [ "$attempt" -lt 5 ]; then
    delay=$((attempt * 30))
    echo "choco install $* failed (attempt $attempt/5); retrying in ${delay}s..." >&2
    sleep "$delay"
  fi
done

echo "choco install $* failed after 5 attempts" >&2
exit 1
