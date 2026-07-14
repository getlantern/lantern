#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${TEST_PATH:-integration_test/vpn/macos_connect_smoke_test.dart}"
ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos}"
RUN_CONNECT_SMOKE="${RUN_CONNECT_SMOKE:-true}"
ENABLE_IP_CHECK="${ENABLE_IP_CHECK:-false}"
FORCE_FULL_TUNNEL="${FORCE_FULL_TUNNEL:-true}"
EXTENSION_TIMEOUT_SECONDS="${EXTENSION_TIMEOUT_SECONDS:-120}"
APP_INSTALL_DIR="${APP_INSTALL_DIR:-/Applications/Lantern.app}"
LANTERN_LOG_DIR="${LANTERN_LOG_DIR:-/Users/Shared/Lantern/Logs}"
DMG_MOUNT_DIR=""

log_step() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

find_first_name() {
  local root="$1"
  local name="$2"

  if [[ -z "$root" || ! -e "$root" ]]; then
    return 1
  fi

  find "$root" -maxdepth 4 -name "$name" -print -quit
}

copy_app_bundle() {
  local source="$1"
  local destination="$2"

  if [[ "$source" == "$destination" ]]; then
    printf '%s\n' "$destination"
    return
  fi

  log_step "Copying Lantern app from $source"
  rm -rf "$destination"
  mkdir -p "$(dirname "$destination")"
  ditto "$source" "$destination"
  xattr -dr com.apple.quarantine "$destination" 2>/dev/null || true
  printf '%s\n' "$destination"
}

extract_app_zip() {
  local zip_path="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  log_step "Extracting Lantern app from $zip_path"
  ditto -x -k "$zip_path" "$tmp_dir"

  local app_path
  app_path="$(find_first_name "$tmp_dir" "Lantern.app" || true)"
  if [[ -z "$app_path" ]]; then
    printf 'Lantern.app not found inside %s\n' "$zip_path" >&2
    return 1
  fi

  copy_app_bundle "$app_path" "$APP_INSTALL_DIR"
}

detach_dmg() {
  if [[ -n "$DMG_MOUNT_DIR" && -d "$DMG_MOUNT_DIR" ]]; then
    local mount_dir="$DMG_MOUNT_DIR"
    hdiutil detach "$mount_dir" -quiet || true
    rmdir "$mount_dir" 2>/dev/null || true
    DMG_MOUNT_DIR=""
  fi
}

copy_app_from_dmg() {
  local dmg_path="$1"
  local mount_dir
  mount_dir="$(mktemp -d)"
  DMG_MOUNT_DIR="$mount_dir"

  log_step "Mounting Lantern DMG $dmg_path"
  hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_dir" >/dev/null

  local app_path
  app_path="$(find_first_name "$mount_dir" "Lantern.app" || true)"
  if [[ -z "$app_path" ]]; then
    printf 'Lantern.app not found inside %s\n' "$dmg_path" >&2
    detach_dmg
    return 1
  fi

  copy_app_bundle "$app_path" "$APP_INSTALL_DIR"
  detach_dmg
}

resolve_app_path() {
  if [[ -n "${APP_PATH:-}" && -x "$APP_PATH/Contents/MacOS/Lantern" ]]; then
    copy_app_bundle "$APP_PATH" "$APP_INSTALL_DIR"
    return
  fi

  local dmg_path
  dmg_path="$(find_first_name "${DMG_ARTIFACT_DIR:-}" "*.dmg" || true)"
  if [[ -n "$dmg_path" ]]; then
    copy_app_from_dmg "$dmg_path"
    return
  fi

  local app_zip
  app_zip="$(find_first_name "${APP_ARTIFACT_DIR:-}" "Lantern.app.zip" || true)"
  if [[ -n "$app_zip" ]]; then
    extract_app_zip "$app_zip"
    return
  fi

  local app_artifact
  app_artifact="$(find_first_name "${APP_ARTIFACT_DIR:-}" "Lantern.app" || true)"
  if [[ -n "$app_artifact" ]]; then
    copy_app_bundle "$app_artifact" "$APP_INSTALL_DIR"
    return
  fi

  local candidates=(
    "build/macos/Build/Products/Release/Lantern.app"
    "build/macos/Build/Products/Debug/Lantern.app"
    "build/macos/Runner.app"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      copy_app_bundle "$candidate" "$APP_INSTALL_DIR"
      return
    fi
  done

  printf 'Lantern.app was not found. Set APP_PATH, or provide APP_ARTIFACT_DIR/DMG_ARTIFACT_DIR.\n' >&2
  return 1
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

  if [[ -d "$LANTERN_LOG_DIR" ]]; then
    cp -R "$LANTERN_LOG_DIR/." "$output_dir/" 2>/dev/null || true
  else
    printf 'No Lantern log directory found at %s\n' "$LANTERN_LOG_DIR" \
      >"$output_dir/missing.txt"
  fi
}

reset_lantern_logs() {
  log_step "Resetting Lantern logs at $LANTERN_LOG_DIR"
  rm -rf "$LANTERN_LOG_DIR"
  mkdir -p "$LANTERN_LOG_DIR"
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
      printf 'System extension approval is missing on this runner. Approve Lantern in System Settings or install the MDM approval profile, then rerun this smoke test.\n' >&2
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
  detach_dmg

  exit "$status"
}

trap on_exit EXIT

mkdir -p "$ARTIFACT_DIR"
reset_lantern_logs
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
