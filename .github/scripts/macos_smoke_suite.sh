#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${TEST_PATH:-integration_test/vpn/macos_connect_smoke_test.dart}"
ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos}"
RUN_CONNECT_SMOKE="${RUN_CONNECT_SMOKE:-true}"
VPN_LIFECYCLE_SMOKE="${VPN_LIFECYCLE_SMOKE:-false}"
VPN_VISION_SMOKE="${VPN_VISION_SMOKE:-false}"
VISION_CONFIG_FILE="/Users/Shared/Lantern/E2E/vision-server-urls"
VISION_CURL_PATH_FILE="/Users/Shared/Lantern/E2E/vision-curl-path"
EXTENSION_TIMEOUT_SECONDS="${EXTENSION_TIMEOUT_SECONDS:-120}"
APP_INSTALL_DIR="${APP_INSTALL_DIR:-/Applications/Lantern.app}"
LANTERN_LOG_DIR="${LANTERN_LOG_DIR:-/Users/Shared/Lantern/Logs}"
LANTERN_IPC_SOCKET="${LANTERN_IPC_SOCKET:-/var/run/lantern/lanternd.sock}"
DMG_MOUNT_DIR=""

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

register_installed_app() {
  local app_path="$1"
  local registry="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  local mode bundle

  # Build and XCTest copies share Lantern's bundle ID. macOS VPN approval must
  # resolve the installed fixture, even after those temporary copies are deleted.
  for mode in Debug Profile Release; do
    "$registry" -u "$PWD/build/macos/Build/Products/$mode/Lantern.app" 2>/dev/null || true
  done
  for bundle in "$HOME"/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/*/Lantern.app; do
    [[ -d "$bundle" ]] || continue
    "$registry" -u "$bundle" 2>/dev/null || true
  done
  log_step "Registering installed Lantern app at $app_path"
  "$registry" -f "$app_path"
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
    --last 10m \
    --info --debug \
    --style syslog \
    --predicate 'subsystem == "org.getlantern.lantern" OR subsystem == "org.getlantern.lantern.PacketTunnel" OR process == "neagent" OR process == "nehelper"' \
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

  if [[ "$VPN_VISION_SMOKE" == "true" ]]; then
    rm -rf "$ARTIFACT_DIR/lantern-logs"
    rm -f "$ARTIFACT_DIR/unified-lantern.log" "$ARTIFACT_DIR/screenshot.png"
  else
    capture_screenshot
  fi
  capture_command "systemextensionsctl-list" systemextensionsctl list
  capture_command "vpn-profiles" scutil --nc list
  capture_command "process-list" ps aux
  capture_command "packet-tunnel-processes" pgrep -fl "org.getlantern.lantern.PacketTunnel"
  capture_command "interfaces" ifconfig
  capture_command "routes" netstat -rn
  if [[ "$VPN_LIFECYCLE_SMOKE" == "true" ]]; then
    cp /Users/Shared/Lantern/E2E/vpn-smoke-*.json "$ARTIFACT_DIR/" 2>/dev/null || true
  fi
  if [[ "$VPN_VISION_SMOKE" != "true" ]]; then
    capture_lantern_logs
    capture_unified_logs
  fi
}

quit_lantern() {
  log_step "Asking Lantern to quit"
  osascript -e 'tell application id "org.getlantern.lantern" to quit' >/dev/null 2>&1 || true
  osascript -e 'tell application "Lantern" to quit' >/dev/null 2>&1 || true
  sleep 2
}

wait_for_vpn_disconnect() {
  local timeout_seconds="${1:-30}"
  local profiles i

  # macOS can keep the system extension alive between sessions. Check the VPN
  # and its IPC socket instead; a resident process does not mean a live tunnel.
  for ((i = 0; i < timeout_seconds; i++)); do
    profiles="$(LC_ALL=C scutil --nc list)" || return 1
    if printf '%s\n' "$profiles" | awk '
      index($0, "[VPN:org.getlantern.lantern]") {
        found = 1
        if ($1 != "(Disconnected)" && $2 != "(Disconnected)") active = 1
      }
      END { exit (!found || active) }
    ' && [[ ! -e "$LANTERN_IPC_SOCKET" ]]; then
      log_step "Lantern VPN is disconnected and its IPC socket is closed"
      return 0
    fi
    sleep 1
  done

  printf '%s\n' "$profiles" >"$ARTIFACT_DIR/vpn-profiles.txt"
  printf 'Lantern VPN is not disconnected or its IPC socket still exists after quit\n' >&2
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
  local app_path="$1"
  local args=(
    "drive"
    "--profile"
    "--use-application-binary=$app_path"
    "--keep-app-running"
    "--driver=test_driver/integration_test.dart"
    "--target=$TEST_PATH"
    "-d"
    "macos"
  )

  # Smoke options are compiled into the signed fixture before it is installed.
  log_step "Running macOS connect smoke: flutter ${args[*]}"
  flutter "${args[@]}"
}

on_exit() {
  local status=$?

  if [[ "$VPN_VISION_SMOKE" == "true" ]]; then
    rm -f "$VISION_CONFIG_FILE" "$VISION_CURL_PATH_FILE"
  fi
  unset JOIN_SERVER_CONFIG_URLS
  if [[ "$status" -ne 0 ]]; then
    # Preserve native permission prompts in the failure screenshot.
    capture_diagnostics "failure"
  fi
  quit_lantern
  if [[ "$VPN_LIFECYCLE_SMOKE" == "true" ]]; then
    rm -f /Users/Shared/Lantern/E2E/vpn-smoke-request.json \
      /Users/Shared/Lantern/E2E/vpn-smoke-request.json.tmp \
      /Users/Shared/Lantern/E2E/vpn-smoke-result.json
  fi
  detach_dmg

  exit "$status"
}

trap on_exit EXIT

if [[ "$VPN_VISION_SMOKE" == "true" ]]; then
  rm -f "$VISION_CONFIG_FILE" "$VISION_CURL_PATH_FILE"
  [[ -n "${VISION_CURL:-}" && -x "$VISION_CURL" ]] || {
    printf 'Vision smoke requires the configured Homebrew curl executable.\n' >&2
    exit 2
  }
  python3 .github/scripts/vision_smoke_config.py --mask --output "$VISION_CONFIG_FILE"
  (umask 077; printf '%s\n' "$VISION_CURL" > "$VISION_CURL_PATH_FILE")
fi
unset JOIN_SERVER_CONFIG_URLS

mkdir -p "$ARTIFACT_DIR"
reset_lantern_logs
capture_command "systemextensionsctl-list-initial" systemextensionsctl list
if [[ "$VPN_LIFECYCLE_SMOKE" == "true" ]]; then
  rm -f /Users/Shared/Lantern/E2E/vpn-smoke-request.json \
    /Users/Shared/Lantern/E2E/vpn-smoke-result.json
fi

app_path="$(resolve_app_path)"
app_executable="$app_path/Contents/MacOS/Lantern"
if [[ ! -x "$app_executable" ]]; then
  printf 'Lantern executable not found at %s\n' "$app_executable" >&2
  exit 1
fi

if [[ "$RUN_CONNECT_SMOKE" == "true" ]]; then
  register_installed_app "$app_path"
  run_system_extension_preflight "$app_executable"
  run_flutter_connect_smoke "$app_path"
else
  log_step "Skipping macOS connect smoke test."
fi

quit_lantern
if [[ "$RUN_CONNECT_SMOKE" == "true" ]]; then
  wait_for_vpn_disconnect 30
fi
capture_diagnostics "success"
