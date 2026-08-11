#!/usr/bin/env bash
set -euo pipefail

readonly APP_PATH="/Applications/Lantern.app"
readonly APP_EXECUTABLE="$APP_PATH/Contents/MacOS/Lantern"
readonly DATA_PATH="/Users/Shared/Lantern"
readonly HANDOFF_PATH="$DATA_PATH/E2E/auto-update-handoff.json"
readonly DEFAULTS_DOMAIN="org.getlantern.lantern"
readonly ROBOT_SOURCE=".github/scripts/macos_sparkle_handoff.applescript"
readonly ROBOT_SCRIPT="${RUNNER_TEMP:?RUNNER_TEMP is required}/macos-sparkle-handoff.scpt"
readonly FIXTURE_DMG="${FIXTURE_DMG:?FIXTURE_DMG is required}"
readonly TARGET_JSON="${TARGET_JSON:?TARGET_JSON is required}"
readonly APPCAST_XML="${APPCAST_XML:?APPCAST_XML is required}"
readonly ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos-auto-update}"
readonly UI_TIMEOUT_SECONDS="${UI_TIMEOUT_SECONDS:-120}"
readonly UPDATE_TIMEOUT_SECONDS="${UPDATE_TIMEOUT_SECONDS:-600}"

[[ "$UI_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  printf 'UI_TIMEOUT_SECONDS must be a positive integer.\n' >&2
  exit 2
}
[[ "$UPDATE_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  printf 'UPDATE_TIMEOUT_SECONDS must be a positive integer.\n' >&2
  exit 2
}

MOUNT_PATH=""
ORIGINAL_PID=""
RELAUNCHED_PID=""
RESULT="failure"

log_e2e() {
  printf '[E2E] %s\n' "$*" >&2
}

guard_ci_paths() {
  [[ "${CI:-}" == "true" && "${GITHUB_ACTIONS:-}" == "true" ]] || {
    printf 'This smoke only runs in GitHub Actions CI.\n' >&2
    exit 2
  }
  [[ "${RUNNER_ENVIRONMENT:-}" == "self-hosted" ]] || {
    printf 'This smoke requires the dedicated self-hosted macOS runner.\n' >&2
    exit 2
  }
  [[ "${LANTERN_AUTO_UPDATE_SMOKE:-}" == "true" ]] || {
    printf 'The explicit auto-update cleanup guard is missing.\n' >&2
    exit 2
  }
  [[ "$APP_PATH" == "/Applications/Lantern.app" && "$DATA_PATH" == "/Users/Shared/Lantern" ]] || {
    printf 'Refusing to use unexpected Lantern paths.\n' >&2
    exit 2
  }
}

lantern_pids() {
  pgrep -f "^${APP_EXECUTABLE}([[:space:]]|$)" 2>/dev/null || true
}

quit_lantern() {
  osascript -e 'tell application id "org.getlantern.lantern" to quit' >/dev/null 2>&1 || true
  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done < <(lantern_pids)
}

wait_for_exit() {
  local pid="$1"
  local deadline=$((SECONDS + $2))
  while kill -0 "$pid" 2>/dev/null; do
    ((SECONDS < deadline)) || return 1
    sleep 1
  done
}

wait_for_new_pid() {
  local excluded_pid="$1"
  local deadline=$((SECONDS + $2))
  while ((SECONDS < deadline)); do
    local pid
    while IFS= read -r pid; do
      if [[ -n "$pid" && "$pid" != "$excluded_pid" ]] && kill -0 "$pid" 2>/dev/null; then
        printf '%s\n' "$pid"
        return 0
      fi
    done < <(lantern_pids)
    sleep 1
  done
  return 1
}

capture_screenshot() {
  local name="$1"
  screencapture -x "$ARTIFACT_DIR/$name.png" \
    2>"$ARTIFACT_DIR/$name-screenshot-error.txt" || true
}

capture_processes() {
  local name="$1"
  { date -u; ps -axo pid=,ppid=,etime=,state=,command=; } \
    >"$ARTIFACT_DIR/processes-$name.txt" 2>&1 || true
}

bundle_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$APP_PATH/Contents/Info.plist"
}

capture_versions() {
  local name="$1"
  {
    printf 'CFBundleVersion=%s\n' "$(bundle_value CFBundleVersion)"
    printf 'CFBundleShortVersionString=%s\n' "$(bundle_value CFBundleShortVersionString)"
    codesign -dvvv "$APP_PATH"
  } >"$ARTIFACT_DIR/versions-$name.txt" 2>&1 || true
}

verify_bundle() {
  local name="$1"
  local expected_build="$2"
  local expected_display="$3"
  [[ "$(bundle_value CFBundleVersion)" == "$expected_build" ]] || {
    printf '%s bundle build did not match %s.\n' "$name" "$expected_build" >&2
    return 1
  }
  [[ "$(bundle_value CFBundleShortVersionString)" == "$expected_display" ]] || {
    printf '%s display version did not match %s.\n' "$name" "$expected_display" >&2
    return 1
  }
  {
    codesign --verify --deep --strict --verbose=4 "$APP_PATH"
    spctl --assess --type execute --verbose=4 "$APP_PATH"
  } >"$ARTIFACT_DIR/signature-$name.txt" 2>&1
}

detach_dmg() {
  if [[ -n "$MOUNT_PATH" && -d "$MOUNT_PATH" ]]; then
    hdiutil detach "$MOUNT_PATH" -quiet >/dev/null 2>&1 || true
    rmdir "$MOUNT_PATH" 2>/dev/null || true
    MOUNT_PATH=""
  fi
}

cleanup() {
  guard_ci_paths
  quit_lantern
  local tracked_pid
  for tracked_pid in "$ORIGINAL_PID" "$RELAUNCHED_PID"; do
    if [[ -n "$tracked_pid" ]] && kill -0 "$tracked_pid" 2>/dev/null; then
      kill -TERM "$tracked_pid" 2>/dev/null || true
      wait_for_exit "$tracked_pid" 10 || kill -KILL "$tracked_pid" 2>/dev/null || true
    fi
  done
  local pid
  while IFS= read -r pid; do
    if [[ -n "$pid" ]] && ! wait_for_exit "$pid" 10; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done < <(lantern_pids)
  rm -rf -- "$APP_PATH"
  rm -rf -- "$DATA_PATH"
  defaults delete "$DEFAULTS_DOMAIN" >/dev/null 2>&1 || true
}

capture_diagnostics() {
  mkdir -p "$ARTIFACT_DIR"
  {
    printf 'result=%s\noriginal_pid=%s\nrelaunched_pid=%s\n' \
      "$RESULT" "$ORIGINAL_PID" "$RELAUNCHED_PID"
  } >"$ARTIFACT_DIR/result.txt"
  capture_processes final
  [[ -d "$APP_PATH" ]] && capture_versions final
  if [[ -d "$DATA_PATH/Logs" ]]; then
    mkdir -p "$ARTIFACT_DIR/lantern-logs"
    cp -R "$DATA_PATH/Logs/." "$ARTIFACT_DIR/lantern-logs/" 2>/dev/null || true
  fi
  if [[ -d "$HOME/Library/Logs/Sparkle" ]]; then
    mkdir -p "$ARTIFACT_DIR/sparkle-logs"
    cp -R "$HOME/Library/Logs/Sparkle/." "$ARTIFACT_DIR/sparkle-logs/" 2>/dev/null || true
  fi
  log show --last 90m --style syslog \
    --predicate 'process == "Lantern" OR process == "Updater" OR process == "Installer" OR process == "Downloader" OR eventMessage CONTAINS[c] "Sparkle" OR subsystem == "org.getlantern.lantern"' \
    >"$ARTIFACT_DIR/unified-lantern-sparkle.log" 2>&1 || true
}

on_exit() {
  local status=$?
  set +e
  capture_diagnostics
  capture_screenshot final
  detach_dmg
  cleanup
  exit "$status"
}
trap on_exit EXIT

install_fixture() {
  MOUNT_PATH="$(mktemp -d)"
  hdiutil attach "$FIXTURE_DMG" -nobrowse -readonly -mountpoint "$MOUNT_PATH" >/dev/null
  local source_app
  source_app="$(find "$MOUNT_PATH" -maxdepth 3 -type d -name Lantern.app -print -quit)"
  [[ -n "$source_app" ]] || return 1
  ditto "$source_app" "$APP_PATH"
  detach_dmg
}

revalidate_target() {
  local recheck="$ARTIFACT_DIR/live-recheck"
  mkdir -p "$recheck"
  python3 scripts/ci/resolve_desktop_update_target.py \
    --platform macos \
    --appcast-url "$(jq -r .appcast_url "$TARGET_JSON")" \
    --appcast-output "$recheck/appcast.xml" \
    --target-output "$recheck/target.json" \
    --pubspec-input pubspec.yaml \
    --pubspec-output "$recheck/pubspec.yaml"
  [[ "$(jq -r .appcast_sha256 "$TARGET_JSON")" == "$(jq -r .appcast_sha256 "$recheck/target.json")" ]] || {
    printf 'The staging beta appcast changed while the fixture was building; rerun the workflow.\n' >&2
    return 1
  }
}

guard_ci_paths
mkdir -p "$ARTIFACT_DIR"
cp "$APPCAST_XML" "$ARTIFACT_DIR/appcast.xml"
cp "$TARGET_JSON" "$ARTIFACT_DIR/resolved-target.json"
osacompile -o "$ROBOT_SCRIPT" "$ROBOT_SOURCE"
revalidate_target

TARGET_BUILD="$(jq -er '.target_build | tostring' "$TARGET_JSON")"
FIXTURE_BUILD="$(jq -er '.fixture_build | tostring' "$TARGET_JSON")"
DISPLAY_VERSION="$(jq -er .display_version "$TARGET_JSON")"
readonly TARGET_BUILD FIXTURE_BUILD DISPLAY_VERSION

cleanup
mkdir -p "$DATA_PATH/E2E"
{
  xcrun stapler validate "$FIXTURE_DMG"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$FIXTURE_DMG"
} >"$ARTIFACT_DIR/fixture-notarization.txt" 2>&1
install_fixture
verify_bundle fixture "$FIXTURE_BUILD" "$DISPLAY_VERSION"
capture_versions fixture

log_e2e "running the Flutter auto-update robot against the installed fixture"
set +e
flutter drive \
  --profile \
  --use-application-binary="$APP_PATH" \
  --keep-app-running \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/auto_update/desktop_auto_update_smoke_test.dart \
  --device-id=macos \
  >"$ARTIFACT_DIR/flutter-drive.log" 2>&1
drive_status=$?
set -e
cat "$ARTIFACT_DIR/flutter-drive.log"
[[ "$drive_status" -eq 0 ]] || exit "$drive_status"

[[ -f "$HANDOFF_PATH" ]] || {
  printf 'Flutter test completed without creating its native handoff.\n' >&2
  exit 1
}
cp "$HANDOFF_PATH" "$ARTIFACT_DIR/auto-update-handoff.json"
if [[ -f "$DATA_PATH/Logs/screenshots/auto-update-before.png" ]]; then
  cp "$DATA_PATH/Logs/screenshots/auto-update-before.png" "$ARTIFACT_DIR/before.png"
fi
ORIGINAL_PID="$(jq -er '.pid | tostring' "$HANDOFF_PATH")"
[[ "$(jq -er .build_number "$HANDOFF_PATH")" == "$FIXTURE_BUILD" ]] || {
  printf 'Flutter test ran against the wrong fixture build.\n' >&2
  exit 1
}
[[ "$(jq -er .display_version "$HANDOFF_PATH")" == "$DISPLAY_VERSION" ]] || {
  printf 'Flutter test ran against the wrong fixture display version.\n' >&2
  exit 1
}
kill -0 "$ORIGINAL_PID"
original_command="$(ps -p "$ORIGINAL_PID" -o command=)"
[[ "$original_command" == "$APP_EXECUTABLE"* ]] || {
  printf 'Flutter handoff PID %s is not the installed Lantern app: %s\n' \
    "$ORIGINAL_PID" "$original_command" >&2
  exit 1
}
capture_processes prompt

log_e2e "waiting for the native Sparkle prompt from process $ORIGINAL_PID"
osascript "$ROBOT_SCRIPT" wait-prompt "$ORIGINAL_PID" "$UI_TIMEOUT_SECONDS" \
  | tee "$ARTIFACT_DIR/sparkle-prompt.txt"
capture_screenshot prompt
osascript "$ROBOT_SCRIPT" install-until-exit "$ORIGINAL_PID" "$UPDATE_TIMEOUT_SECONDS" \
  2>&1 | tee "$ARTIFACT_DIR/sparkle-install.txt"

log_e2e "waiting for Sparkle to replace and relaunch Lantern"
if kill -0 "$ORIGINAL_PID" 2>/dev/null; then
  printf 'Original Lantern process is still running after Sparkle completed.\n' >&2
  exit 1
fi
RELAUNCHED_PID="$(wait_for_new_pid "$ORIGINAL_PID" "$UI_TIMEOUT_SECONDS")"
osascript "$ROBOT_SCRIPT" wait-main "$RELAUNCHED_PID" "$UI_TIMEOUT_SECONDS" \
  | tee "$ARTIFACT_DIR/main-window-after.txt"
verify_bundle updated "$TARGET_BUILD" "$DISPLAY_VERSION"
capture_versions updated
capture_processes after
capture_screenshot after

RESULT="success"
log_e2e "auto-update smoke passed: build $FIXTURE_BUILD -> $TARGET_BUILD"
