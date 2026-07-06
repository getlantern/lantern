#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${TEST_PATH:-integration_test/vpn/macos_connect_smoke_test.dart}"
ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos}"
RUN_CONNECT_SMOKE="${RUN_CONNECT_SMOKE:-true}"
ENABLE_IP_CHECK="${ENABLE_IP_CHECK:-false}"
FORCE_FULL_TUNNEL="${FORCE_FULL_TUNNEL:-true}"
EXTENSION_TIMEOUT_SECONDS="${EXTENSION_TIMEOUT_SECONDS:-120}"

log_step() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

resolve_app_path() {
  if [[ -n "${APP_PATH:-}" ]]; then
    printf '%s\n' "$APP_PATH"
    return
  fi

  local candidates=(
    "build/macos/Build/Products/Release/Lantern.app"
    "build/macos/Build/Products/Debug/Lantern.app"
    "build/macos/Runner.app"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  printf '%s\n' "${candidates[0]}"
}

capture_command() {
  local name="$1"
  shift

  log_step "Capturing $name"
  "$@" >"$ARTIFACT_DIR/$name.txt" 2>&1 || true
}

capture_lantern_logs() {
  local output_dir="$ARTIFACT_DIR/lantern-logs"
  mkdir -p "$output_dir"

  if [[ -d "/Users/Shared/Lantern/Logs" ]]; then
    cp -R "/Users/Shared/Lantern/Logs/." "$output_dir/" 2>/dev/null || true
  else
    printf 'No Lantern log directory found at /Users/Shared/Lantern/Logs\n' \
      >"$output_dir/missing.txt"
  fi
}

capture_unified_logs() {
  log_step "Capturing unified logs"
  log show \
    --last 30m \
    --style syslog \
    --predicate 'subsystem == "org.getlantern.lantern" OR subsystem == "org.getlantern.lantern.PacketTunnel"' \
    >"$ARTIFACT_DIR/unified-lantern.log" 2>&1 || true
}

capture_screenshot() {
  log_step "Capturing screenshot"
  screencapture -x "$ARTIFACT_DIR/screenshot.png" 2>/dev/null || true
}

capture_diagnostics() {
  local reason="$1"

  mkdir -p "$ARTIFACT_DIR"
  log_step "Capturing diagnostics: $reason"
  {
    printf 'reason=%s\n' "$reason"
    date
  } >"$ARTIFACT_DIR/diagnostics.txt"

  capture_command "systemextensionsctl-list" systemextensionsctl list
  capture_command "process-list" ps aux
  capture_command "packet-tunnel-processes" pgrep -fl "org.getlantern.lantern.PacketTunnel"
  capture_lantern_logs
  capture_unified_logs
  capture_screenshot
}

quit_lantern() {
  log_step "Asking Lantern to quit"
  osascript -e 'tell application id "org.getlantern.lantern" to quit' >/dev/null 2>&1 || true
  osascript -e 'tell application "Lantern" to quit' >/dev/null 2>&1 || true
  sleep 2
}

packet_tunnel_processes() {
  pgrep -fl "org.getlantern.lantern.PacketTunnel" 2>/dev/null || true
}

wait_for_packet_tunnel_exit() {
  local timeout_seconds="${1:-30}"

  for ((i = 0; i < timeout_seconds; i++)); do
    if [[ -z "$(packet_tunnel_processes)" ]]; then
      log_step "PacketTunnel is not running"
      return 0
    fi
    sleep 1
  done

  packet_tunnel_processes >"$ARTIFACT_DIR/packet-tunnel-still-running.txt"
  printf 'PacketTunnel was still running after disconnect/quit\n' >&2
  return 1
}

run_system_extension_preflight() {
  local app_executable="$1"
  local output="$ARTIFACT_DIR/system-extension-preflight.jsonl"

  log_step "Running macOS system extension preflight"
  set +e
  "$app_executable" \
    --smoke-activate-system-extension \
    --timeout-seconds "$EXTENSION_TIMEOUT_SECONDS" \
    >"$output" 2>&1
  local exit_code=$?
  set -e

  cat "$output"
  case "$exit_code" in
    0)
      return 0
      ;;
    20)
      printf 'System extension requires manual approval before this smoke test can connect.\n' >&2
      ;;
    21)
      printf 'System extension activation requires a reboot before this smoke test can connect.\n' >&2
      ;;
    124)
      printf 'System extension preflight timed out after %s seconds.\n' "$EXTENSION_TIMEOUT_SECONDS" >&2
      ;;
    *)
      printf 'System extension preflight failed with exit code %s.\n' "$exit_code" >&2
      ;;
  esac

  return "$exit_code"
}

run_flutter_connect_smoke() {
  local args=(
    "test"
    "$TEST_PATH"
    "-d"
    "macos"
    "--reporter=expanded"
    "--dart-define=DISABLE_SYSTEM_TRAY=true"
  )

  if [[ "$ENABLE_IP_CHECK" == "true" ]]; then
    args+=("--dart-define=ENABLE_IP_CHECK=true")
  fi

  if [[ "$FORCE_FULL_TUNNEL" == "true" ]]; then
    args+=("--dart-define=SMOKE_FORCE_FULL_TUNNEL=true")
  fi

  log_step "Running macOS connect smoke: flutter ${args[*]}"
  flutter "${args[@]}"
}

on_exit() {
  local status=$?

  quit_lantern
  if [[ "$status" -ne 0 ]]; then
    capture_diagnostics "failure"
  fi

  exit "$status"
}

trap on_exit EXIT

mkdir -p "$ARTIFACT_DIR"
capture_command "systemextensionsctl-list-initial" systemextensionsctl list

app_path="$(resolve_app_path)"
app_executable="$app_path/Contents/MacOS/Lantern"
if [[ ! -x "$app_executable" ]]; then
  printf 'Lantern executable not found at %s\n' "$app_executable" >&2
  exit 1
fi

if [[ "$RUN_CONNECT_SMOKE" == "true" ]]; then
  run_system_extension_preflight "$app_executable"
  run_flutter_connect_smoke
else
  log_step "Skipping macOS connect smoke test."
fi

quit_lantern
wait_for_packet_tunnel_exit 30
capture_diagnostics "success"
