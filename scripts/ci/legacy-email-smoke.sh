#!/usr/bin/env bash
set -euo pipefail

[[ $(uname -s) == Linux ]] || { echo 'This smoke test requires Linux.' >&2; exit 1; }
cloud_dir=$(cd "${1:?Cloud checkout required}" && pwd)
fixture_binary=${2:?Compiled API fixture required}
: "${LEGACY_EMAIL_FIXTURE_DIR:?Isolated fixture directory required}"
[[ ! -e "$LEGACY_EMAIL_FIXTURE_DIR" ]] || { echo 'Fixture directory must be new.' >&2; exit 1; }
[[ ! -S /run/lantern/lanternd.sock ]] || { echo 'A Lantern daemon is already running.' >&2; exit 1; }
for binary in bin/linux/liblantern.so bin/linux-amd64/lanternd; do
  go version -m "$binary" | grep -Eq -- '-tags=.*lantern_e2e' || {
    echo "$binary must be built with lantern_e2e." >&2
    exit 1
  }
done
mkdir -p "$LEGACY_EMAIL_FIXTURE_DIR"/{native,logs,app,app-config}
export XDG_DATA_HOME="$LEGACY_EMAIL_FIXTURE_DIR/app"
export XDG_CONFIG_HOME="$LEGACY_EMAIL_FIXTURE_DIR/app-config"
unset RADIANCE_DATA_PATH RADIANCE_LOG_PATH
export RADIANCE_DISABLE_FETCH_CONFIG=true
export RADIANCE_LOG_TO_STDOUT=true
export RADIANCE_PRINT_CURL=false
export LANG=C.UTF-8 LC_ALL=C.UTF-8
fixture_pid= daemon_pid=

stop_daemon() {
  if [[ -n "$daemon_pid" ]]; then
    kill "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
    daemon_pid=
  fi
}

cleanup() {
  stop_daemon
  if [[ -n "$fixture_pid" ]]; then
    kill "$fixture_pid" 2>/dev/null || true
    wait "$fixture_pid" 2>/dev/null || true
  fi
  local worktree_hash
  worktree_hash=$(printf '%s' "$cloud_dir" | sha256sum)
  COMPOSE_PROJECT_NAME="lantern-cloud-test-${worktree_hash:0:12}" \
    docker compose -f "$cloud_dir/docker-compose-tests.yml" down --volumes >"$LEGACY_EMAIL_FIXTURE_DIR/cleanup.log" 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM

(cd "$cloud_dir" && exec bin/testsetup "$fixture_binary" \
  -test.run '^TestLegacyEmailAppFixture$' -test.v -test.timeout 20m) \
  >"$LEGACY_EMAIL_FIXTURE_DIR/api.log" 2>&1 &
fixture_pid=$!
for ((attempt = 0; attempt < 180; attempt++)); do
  [[ -f "$LEGACY_EMAIL_FIXTURE_DIR/ready.json" ]] && break
  if ! kill -0 "$fixture_pid" 2>/dev/null; then
    cat "$LEGACY_EMAIL_FIXTURE_DIR/api.log"
    echo 'Account API fixture exited before readiness.' >&2
    exit 1
  fi
  sleep 1
done
test -f "$LEGACY_EMAIL_FIXTURE_DIR/ready.json"

python3 - "$LEGACY_EMAIL_FIXTURE_DIR" <<'PY'
import json
import os
import sys
from pathlib import Path

directory = Path(sys.argv[1])
fixture = json.loads((directory / "ready.json").read_text())
settings = {
    "user_id": fixture["userId"],
    "token": fixture["proToken"],
    "device_id": fixture["deviceId"],
    "email": fixture["email"],
    "user_level": "pro",
    "locale": "en-US",
    "telemetry_enabled": False,
    "auto_connect": False,
    "devices": [{"ID": d["id"], "Name": d["name"]} for d in fixture["devices"]],
    "user_data": fixture["userData"],
}
path = directory / "native/settings.json"
path.write_text(json.dumps(settings))
os.chmod(path, 0o600)
PY
LANTERN_E2E_API_URL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["apiUrl"])' "$LEGACY_EMAIL_FIXTURE_DIR/ready.json")
export LANTERN_E2E_API_URL
sudo install -d -o "$(id -u)" -g "$(id -g)" /run/lantern

start_daemon() {
  bin/linux-amd64/lanternd run \
    --data-path "$LEGACY_EMAIL_FIXTURE_DIR/native" --log-path "$LEGACY_EMAIL_FIXTURE_DIR/logs" --log-level info \
    >>"$LEGACY_EMAIL_FIXTURE_DIR/daemon.log" 2>&1 &
  daemon_pid=$!
  for ((attempt = 0; attempt < 60; attempt++)); do
    kill -0 "$daemon_pid" || { cat "$LEGACY_EMAIL_FIXTURE_DIR/daemon.log"; exit 1; }
    if curl --silent --show-error --fail --max-time 2 --http2-prior-knowledge \
      --unix-socket /run/lantern/lanternd.sock http://localhost/account/user \
      > /dev/null 2>"$LEGACY_EMAIL_FIXTURE_DIR/daemon-ready.log"; then
      return
    fi
    sleep 1
  done
  cat "$LEGACY_EMAIL_FIXTURE_DIR/daemon-ready.log" "$LEGACY_EMAIL_FIXTURE_DIR/daemon.log" >&2
  echo 'Lantern daemon did not become ready.' >&2
  exit 1
}

for phase in bind verify; do
  start_daemon
  timeout --signal=TERM --kill-after=30s 8m xvfb-run -a \
    flutter test integration_test/auth/legacy_email_local_smoke_test.dart -d linux --reporter=expanded \
    --dart-define=DISABLE_SYSTEM_TRAY=true \
    --dart-define="LEGACY_EMAIL_FIXTURE_DIR=$LEGACY_EMAIL_FIXTURE_DIR" \
    --dart-define="LEGACY_EMAIL_PHASE=$phase" \
    2>&1 | tee "$LEGACY_EMAIL_FIXTURE_DIR/flutter-$phase.log"
  stop_daemon
done
wait "$fixture_pid"
fixture_pid=
python3 - "$LEGACY_EMAIL_FIXTURE_DIR/result.json" <<'PY'
import json
import sys

result = json.load(open(sys.argv[1]))
if result.get("success") is not True:
    raise SystemExit(result.get("error", "Fixture verification failed"))
print("Legacy account binding, restart, and password login passed.")
PY
