#!/usr/bin/env bash
# retry-transient.sh — run a command, retrying with backoff when it fails.
#
# Usage: retry-transient.sh [-n ATTEMPTS] [-m REGEX] -- COMMAND [ARGS...]
#
# With -m, a failure is retried only if the command's combined output matches
# the extended regex REGEX; any other failure is returned at once, so real
# build errors do not pay for extra attempts. Without -m, every failure is
# retried. Output is streamed as it is produced.
set -u

attempts=3
match=

while getopts "n:m:" opt; do
  case "$opt" in
    n)
      case "$OPTARG" in
        ""|*[!0-9]*|0) echo "$0: -n must be a positive integer" >&2; exit 2 ;;
      esac
      attempts=$OPTARG ;;
    m) match=$OPTARG ;;
    *) echo "usage: $0 [-n ATTEMPTS] [-m REGEX] -- COMMAND [ARGS...]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ "${1:-}" = "--" ] && shift
if [ $# -eq 0 ]; then
  echo "usage: $0 [-n ATTEMPTS] [-m REGEX] -- COMMAND [ARGS...]" >&2
  exit 2
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT

attempt=1
while :; do
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] && exit 0

  if [ -n "$match" ] && ! grep -qE -- "$match" "$log"; then
    exit "$status"
  fi
  if [ "$attempt" -ge "$attempts" ]; then
    echo "$1: giving up after $attempt attempts (exit $status)" >&2
    exit "$status"
  fi
  delay=$((attempt * 30))
  echo "$1: transient failure on attempt $attempt/$attempts (exit $status); retrying in ${delay}s" >&2
  sleep "$delay"
  attempt=$((attempt + 1))
done
