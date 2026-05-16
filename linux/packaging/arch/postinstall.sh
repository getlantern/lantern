#!/bin/sh
set -e

LOG_LEVEL="$(cat /usr/lib/lantern/lanternd-log-level 2>/dev/null || printf '%s' trace)"
/usr/lib/lantern/lanternd install --log-level="$LOG_LEVEL" >/dev/null 2>&1 || true
