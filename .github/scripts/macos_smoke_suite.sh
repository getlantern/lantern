#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${TEST_PATH:-integration_test/vpn/macos_connect_smoke_test.dart}"
ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos}"
RUN_CONNECT_SMOKE="${RUN_CONNECT_SMOKE:-true}"
RUN_PAYMENT_CHECKOUT_SMOKE="${RUN_PAYMENT_CHECKOUT_SMOKE:-false}"
ENABLE_IP_CHECK="${ENABLE_IP_CHECK:-false}"
FORCE_FULL_TUNNEL="${FORCE_FULL_TUNNEL:-true}"
EXTENSION_TIMEOUT_SECONDS="${EXTENSION_TIMEOUT_SECONDS:-120}"
APP_INSTALL_DIR="${APP_INSTALL_DIR:-/Applications/Lantern.app}"
LANTERN_DATA_DIR="${LANTERN_DATA_DIR:-/Users/Shared/Lantern}"
LANTERN_LOG_DIR="${LANTERN_LOG_DIR:-$LANTERN_DATA_DIR/Logs}"
DMG_MOUNT_DIR=""
LANTERN_PID=""

if ! [[ "$EXTENSION_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  printf 'EXTENSION_TIMEOUT_SECONDS must be a positive integer, got %q.\n' \
    "$EXTENSION_TIMEOUT_SECONDS" >&2
  exit 2
fi

log_step() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

trim_trailing_slashes() {
  local path="$1"
  while [[ "$path" != "/" && "$path" == */ ]]; do
    path="${path%/}"
  done
  printf '%s\n' "$path"
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
  local source
  local destination
  source="$(trim_trailing_slashes "$1")"
  destination="$(trim_trailing_slashes "$2")"

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

reset_lantern_data() {
  log_step "Resetting Lantern data at $LANTERN_DATA_DIR"
  rm -rf "$LANTERN_DATA_DIR"
  mkdir -p "$LANTERN_LOG_DIR"
  touch "$LANTERN_DATA_DIR/.radiance_env"
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
  if ! pgrep -x Lantern >/dev/null 2>&1; then
    return
  fi

  log_step "Asking Lantern to quit"
  if ! osascript -e 'tell application id "org.getlantern.lantern" to quit' \
    >/dev/null 2>&1; then
    osascript -e 'tell application "Lantern" to quit' >/dev/null 2>&1 || true
  fi
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

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local command_pid=$!
  local deadline=$((SECONDS + timeout_seconds))

  while kill -0 "$command_pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      kill -TERM "$command_pid" 2>/dev/null || true
      sleep 2
      if kill -0 "$command_pid" 2>/dev/null; then
        kill -KILL "$command_pid" 2>/dev/null || true
      fi
      wait "$command_pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
  done

  local exit_code=0
  wait "$command_pid" || exit_code=$?
  return "$exit_code"
}

run_system_extension_preflight() {
  local app_executable="$1"
  local output="$ARTIFACT_DIR/system-extension-preflight.jsonl"
  local process_timeout=$((EXTENSION_TIMEOUT_SECONDS + 10))

  log_step "Running macOS system extension preflight"
  set +e
  run_with_timeout "$process_timeout" "$app_executable" \
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
      printf 'System extension preflight exceeded the %s-second wrapper deadline (activation timeout: %s seconds), followed by a 2-second termination grace period.\n' \
        "$process_timeout" "$EXTENSION_TIMEOUT_SECONDS" >&2
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

wait_for_log_pattern() {
  local pattern="$1"
  local timeout_seconds="$2"
  local log_file="${3:-$LANTERN_LOG_DIR/flutter.log}"
  local flutter_log="$LANTERN_LOG_DIR/flutter.log"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if [[ -n "$LANTERN_PID" ]] && ! kill -0 "$LANTERN_PID" 2>/dev/null; then
      printf 'Lantern exited before its checkout screen was ready.\n' >&2
      return 1
    fi
    if [[ -f "$log_file" ]] && grep -Eq "$pattern" "$log_file"; then
      return 0
    fi
    if [[ -f "$flutter_log" ]] && grep -Eq \
      'PAYMENT_CHECKOUT_SMOKE event=(rejected|bootstrap_error)' "$flutter_log"; then
      tail -n 80 "$flutter_log" >&2
      return 1
    fi
    sleep 1
  done

  printf 'Timed out waiting for %s in %s.\n' "$pattern" "$log_file" >&2
  return 1
}

wait_for_lantern_process() {
  local app_executable="$1"
  local timeout_seconds="$2"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    local pid
    while read -r pid; do
      if [[ "$(ps -p "$pid" -o command= 2>/dev/null)" == "$app_executable"* ]]; then
        LANTERN_PID="$pid"
        return 0
      fi
    done < <(pgrep -x Lantern 2>/dev/null || true)
    sleep 1
  done

  printf 'Lantern did not start from %s.\n' "$app_executable" >&2
  return 1
}

press_accessibility_control() {
  local identifier="$1"
  local timeout_seconds="$2"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if osascript - "$LANTERN_PID" "$identifier" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
  set targetPID to item 1 of argv as integer
  set targetIdentifier to item 2 of argv

  tell application "System Events"
    set targetProcess to first application process whose unix id is targetPID
    set frontmost of targetProcess to true
    repeat with candidate in entire contents of front window of targetProcess
      try
        if value of attribute "AXIdentifier" of candidate is targetIdentifier then
          perform action "AXPress" of candidate
          return
        end if
      end try
    end repeat
  end tell

  error "Accessibility control not found: " & targetIdentifier
end run
APPLESCRIPT
    then
      return 0
    fi
    sleep 1
  done

  printf 'Unable to press macOS accessibility control %s.\n' "$identifier" >&2
  return 1
}

wait_for_checkout_document() {
  local host_pattern="$1"
  local timeout_seconds="$2"
  local log_file="$LANTERN_LOG_DIR/flutter.log"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if [[ -n "$LANTERN_PID" ]] && ! kill -0 "$LANTERN_PID" 2>/dev/null; then
      printf 'Lantern exited while checkout was loading.\n' >&2
      return 1
    fi
    if [[ -f "$log_file" ]] && grep -Eq \
      'PAYMENT_WEBVIEW_SMOKE event=(navigation_error|process_error|document_error)' "$log_file"; then
      tail -n 100 "$log_file" >&2
      return 1
    fi

    local line
    line="$(grep 'PAYMENT_WEBVIEW_SMOKE event=load_stop' "$log_file" 2>/dev/null | tail -n 1 || true)"
    if [[ -n "$line" ]]; then
      local host document_length
      host="$(sed -E 's/.* host=([^ ]+).*/\1/' <<<"$line")"
      document_length="$(sed -E 's/.* document_length=([-0-9]+).*/\1/' <<<"$line")"
      if [[ "$host" =~ $host_pattern ]] &&
        [[ "$document_length" =~ ^[0-9]+$ ]] &&
        ((document_length > 0)); then
        return 0
      fi
    fi
    sleep 1
  done

  printf 'No non-empty checkout document loaded from %s.\n' "$host_pattern" >&2
  return 1
}

run_payment_checkout_case() {
  local app_path="$1"
  local provider="$2"
  local host_pattern="$3"
  local app_executable="$app_path/Contents/MacOS/Lantern"
  local case_dir="$ARTIFACT_DIR/payment-$provider"
  local run_id
  run_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"

  mkdir -p "$case_dir"
  quit_lantern
  reset_lantern_data
  log_step "Opening $provider checkout in the macOS app"

  open -F -n \
    -o "$case_dir/process.log" \
    --stderr "$case_dir/process-error.log" \
    "$app_path" \
    --args \
    "--payment-checkout-smoke=$provider" \
    "--payment-checkout-run-id=$run_id"
  wait_for_lantern_process "$app_executable" 30

  wait_for_log_pattern \
    'Setting up Radiance opts=.*Env:stage' 60 "$case_dir/process-error.log"
  wait_for_log_pattern \
    "PAYMENT_CHECKOUT_SMOKE event=screen_ready provider=$provider run_id=$run_id" 120
  screencapture -x "$case_dir/payment-method.png" 2>/dev/null || true

  press_accessibility_control "payment-checkout-$provider" 30
  wait_for_checkout_document "$host_pattern" 180
  screencapture -x "$case_dir/checkout.png" 2>/dev/null || true

  cp -R "$LANTERN_LOG_DIR/." "$case_dir/" 2>/dev/null || true
  stop_payment_lantern
}

run_payment_checkout_smoke() {
  local app_path="$1"

  run_payment_checkout_case \
    "$app_path" stripe '^checkout\.stripe\.com$'
  run_payment_checkout_case \
    "$app_path" shepherd '(^|\.)m62mrsf\.com$'
}

stop_payment_lantern() {
  quit_lantern
  if [[ -z "$LANTERN_PID" ]]; then
    return
  fi

  if kill -0 "$LANTERN_PID" 2>/dev/null; then
    kill -TERM "$LANTERN_PID" 2>/dev/null || true
    for _ in {1..5}; do
      kill -0 "$LANTERN_PID" 2>/dev/null || break
      sleep 1
    done
  fi
  if kill -0 "$LANTERN_PID" 2>/dev/null; then
    kill -KILL "$LANTERN_PID" 2>/dev/null || true
  fi
  wait "$LANTERN_PID" 2>/dev/null || true
  LANTERN_PID=""
}

on_exit() {
  local status=$?

  if [[ "$status" -ne 0 ]]; then
    capture_diagnostics "failure"
  fi
  stop_payment_lantern
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

if [[ "$RUN_PAYMENT_CHECKOUT_SMOKE" == "true" ]]; then
  run_payment_checkout_smoke "$app_path"
else
  log_step "Skipping macOS payment checkout smoke test."
fi

quit_lantern
wait_for_packet_tunnel_exit 30
capture_diagnostics "success"
