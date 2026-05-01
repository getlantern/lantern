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
#   radiance-env poll                              # trigger an immediate config-fetch
#   radiance-env -h | --help
#
# Examples:
#   radiance-env
#   radiance-env force-track unbounded-linode-free
#   radiance-env poll                              # don't wait for the next adaptive interval
#   radiance-env set RADIANCE_COUNTRY=IR RADIANCE_FEATURE_OVERRIDES=force_track=eevee

set -euo pipefail

usage() {
  # Print the contiguous comment block starting at line 3 (after the
  # shebang + blank-comment header) until the first non-comment line.
  # Using a fixed line range here was lossy: the previous `sed -n '3,18p'`
  # cut off the Examples section, so `-h/--help` silently hid half the
  # documented usage. Driving the range off the comment shape instead
  # keeps the help text and the header in sync as either grows.
  awk '
    NR <= 2 { next }
    /^#/    { sub(/^# ?/, ""); print; next }
              { exit }
  ' "$0"
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
  # The radiance IPC server speaks unencrypted HTTP/2 only (it's configured
  # via http.Protocols.SetUnencryptedHTTP2(true) in radiance/ipc/server.go).
  # An HTTP/1.1 request would be accepted at the TCP layer and then dropped
  # without an HTTP response, surfacing as `curl: (52) Empty reply from
  # server` — which is what we hit before adding --http2-prior-knowledge.
  $SUDO curl -sS --fail-with-body --http2-prior-knowledge --unix-socket "$SOCK" "$@"
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
    # Validate the key shape: empty keys would silently produce invalid
    # JSON like {"":"v"} which the server rejects with an unhelpful error,
    # and non-shell-safe characters would slip through quoting in
    # follow-on tooling. Match the conservative POSIX env-var pattern.
    if [[ -z "$key" || ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "radiance-env set: invalid env var name '$key' (must match [A-Za-z_][A-Za-z0-9_]*)" >&2
      exit 64
    fi
    # Reject values that contain control chars (newline, tab, CR, etc.).
    # The minimal escaping below only handles backslashes and quotes, so a
    # raw newline would break the JSON request. Radiance env values are
    # short ASCII strings in practice (force_track names, country codes,
    # semvers); the operator hitting this almost certainly fat-fingered
    # something rather than legitimately wanting a multiline value.
    if [[ "$val" =~ [[:cntrl:]] ]]; then
      echo "radiance-env set: value for '$key' contains control characters; not supported" >&2
      exit 64
    fi
    # JSON-escape the surviving printable characters that need it.
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

cmd_poll() {
  # Trigger an immediate /v1/config-new poll. Without this, a setting
  # change (e.g. via `force-track`) only takes effect on the next
  # scheduled fetch — which can be minutes away under the adaptive
  # interval. The endpoint is configUpdateEndpoint in
  # radiance/ipc/server.go and returns 200 with no body on success.
  curl_sock -X POST http://lantern/config/update -o /dev/null -w "config poll: HTTP %{http_code}\n"
}

case "${1:-get}" in
  -h|--help) usage 0 ;;
  get) shift; cmd_get "$@" ;;
  set) shift; cmd_set "$@" ;;
  force-track) shift; cmd_force_track "$@" ;;
  poll) shift; cmd_poll "$@" ;;
  *) echo "radiance-env: unknown command: $1" >&2; usage 64 ;;
esac
