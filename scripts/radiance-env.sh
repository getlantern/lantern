#!/usr/bin/env bash
#
# radiance-env — show or patch radiance daemon env vars over its IPC socket.
#
# Talks to the localapi server in radiance/ipc/server.go. Useful for setting
# things like RADIANCE_FEATURE_OVERRIDES (e.g. force_track=...) on a
# release-build Lantern install where the dev-mode UI isn't exposed.
#
# Usage:
#   radiance-env                                   # show current env
#   radiance-env get                               # same
#   radiance-env set KEY=VALUE [KEY=VALUE ...]     # patch one or more vars
#   radiance-env force-track <track-name>          # shortcut for the common case
#   radiance-env force-track ""                    # clear force_track
#   radiance-env -h | --help
#
# Examples:
#   radiance-env
#   radiance-env force-track unbounded-linode-free
#   radiance-env set RADIANCE_COUNTRY=IR RADIANCE_FEATURE_OVERRIDES=force_track=eevee

set -euo pipefail

usage() {
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# Surface help before any platform/socket checks so `-h` works without
# the daemon running.
case "${1:-}" in
  -h|--help) usage 0 ;;
esac

# ─── platform-specific socket path ──────────────────────────────────────────
# radiance/ipc/socket.go pins the path on every non-windows platform; macOS
# and Linux both land here. Windows uses a named pipe and is intentionally
# unsupported by this script.
case "$(uname -s)" in
  Darwin|Linux)
    SOCK="/var/run/lantern/lanternd.sock"
    ;;
  *)
    echo "radiance-env: unsupported platform $(uname -s); see scripts/run-windows-dev.ps1 for windows" >&2
    exit 2
    ;;
esac

if [[ ! -S "$SOCK" ]]; then
  echo "radiance-env: socket $SOCK not found — is the Lantern daemon running?" >&2
  exit 3
fi

# Pick sudo only if we can't read/write the socket as the current user.
# The socket is chmod 0666 by setPermissions() so this should usually be a no-op,
# but radiance can run as root on macOS for TUN ownership and may produce a
# socket whose perms don't propagate (race on first start).
SUDO=""
if [[ ! -r "$SOCK" || ! -w "$SOCK" ]]; then
  SUDO="sudo"
fi

curl_sock() {
  $SUDO curl -sS --fail-with-body --unix-socket "$SOCK" "$@"
}

pretty() {
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    cat
  fi
}

cmd_get() {
  curl_sock http://lantern/env | pretty
}

cmd_set() {
  if [[ $# -eq 0 ]]; then
    echo "radiance-env set: need at least one KEY=VALUE" >&2
    exit 64
  fi
  # Build {"K":"V","K2":"V2",...} without depending on jq, but escape values.
  local body="{"
  local first=1
  for kv in "$@"; do
    if [[ "$kv" != *=* ]]; then
      echo "radiance-env set: arg '$kv' is not KEY=VALUE" >&2
      exit 64
    fi
    local key="${kv%%=*}"
    local val="${kv#*=}"
    # JSON-escape backslashes and double quotes in the value. Other control
    # chars are left as-is — radiance's env values are short ASCII strings
    # in practice (force_track names, country codes, semvers).
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    if (( first )); then
      first=0
    else
      body+=","
    fi
    body+="\"${key}\":\"${val}\""
  done
  body+="}"

  curl_sock -X PATCH http://lantern/env \
    -H "Content-Type: application/json" \
    -d "$body" | pretty
}

cmd_force_track() {
  if [[ $# -ne 1 ]]; then
    echo "radiance-env force-track: takes exactly one arg (track name, or \"\" to clear)" >&2
    exit 64
  fi
  local track="$1"
  if [[ -z "$track" ]]; then
    cmd_set "RADIANCE_FEATURE_OVERRIDES="
  else
    cmd_set "RADIANCE_FEATURE_OVERRIDES=force_track=${track}"
  fi
}

case "${1:-get}" in
  -h|--help) usage 0 ;;
  get) shift; cmd_get "$@" ;;
  set) shift; cmd_set "$@" ;;
  force-track) shift; cmd_force_track "$@" ;;
  *) echo "radiance-env: unknown command: $1" >&2; usage 64 ;;
esac
