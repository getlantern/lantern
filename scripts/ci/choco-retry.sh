#!/usr/bin/env bash
# choco-retry.sh — `choco install` with retries and backoff.
#
# community.chocolatey.org 504s intermittently, and a single gateway timeout
# has failed two consecutive Windows release builds (v9.1.18-beta 2026-07-26:
# mingw + yq; v9.1.19-beta 2026-08-05: yq). A transient feed error should cost
# a retry, not the build.
set -u

for attempt in 1 2 3 4 5; do
  choco install "$@"
  code=$?
  # 1641/3010 are MSI "success, reboot initiated/required" — fine on CI.
  case $code in
    0 | 1641 | 3010) exit 0 ;;
  esac
  if [ "$attempt" -lt 5 ]; then
    delay=$((attempt * 30))
    echo "choco install $* exited $code (attempt $attempt/5); retrying in ${delay}s..." >&2
    sleep "$delay"
  fi
done

echo "choco install $* failed after 5 attempts" >&2
exit 1
