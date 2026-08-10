#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${TEST_PATH:-integration_test/payment/desktop_stripe_checkout_smoke_test.dart}"
ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos-payment-checkout}"
LANTERN_DATA_DIR="/Users/Shared/Lantern"
LANTERN_LOG_DIR="$LANTERN_DATA_DIR/Logs"
SCREENSHOT_READY_FILE="$LANTERN_DATA_DIR/.checkout-screenshot-ready"
SCREENSHOT_CAPTURED_FILE="$LANTERN_DATA_DIR/.checkout-screenshot-captured"
SCREENSHOT_PATH="$ARTIFACT_DIR/stripe-checkout.png"
SCREENSHOT_WATCHER_PID=""

capture_checkout_screenshot() {
  local deadline=$((SECONDS + 300))
  while ((SECONDS < deadline)); do
    if [[ -f "$SCREENSHOT_READY_FILE" ]]; then
      if /usr/sbin/screencapture -x "$SCREENSHOT_PATH"; then
        printf 'Stripe Checkout screenshot captured at %s\n' "$SCREENSHOT_PATH" \
          >"$ARTIFACT_DIR/screenshot-status.txt"
      else
        printf 'Unable to capture the Stripe Checkout screenshot\n' \
          >"$ARTIFACT_DIR/screenshot-status.txt"
      fi
      touch "$SCREENSHOT_CAPTURED_FILE"
      return
    fi
    sleep 0.1
  done
}

cleanup() {
  local status=$?
  if [[ -n "$SCREENSHOT_WATCHER_PID" ]]; then
    kill "$SCREENSHOT_WATCHER_PID" 2>/dev/null || true
    wait "$SCREENSHOT_WATCHER_PID" 2>/dev/null || true
  fi
  mkdir -p "$ARTIFACT_DIR"
  if [[ ! -f "$SCREENSHOT_PATH" ]]; then
    /usr/sbin/screencapture -x "$SCREENSHOT_PATH" 2>/dev/null || true
  fi
  if [[ -d "$LANTERN_LOG_DIR" ]]; then
    cp -R "$LANTERN_LOG_DIR/." "$ARTIFACT_DIR/" 2>/dev/null || true
  fi
  rm -rf "$LANTERN_DATA_DIR"
  exit "$status"
}

# This script wipes $LANTERN_DATA_DIR (real Lantern app data) and kills any
# running Lantern — refuse to run outside CI.
if [[ -z "${CI:-}" ]]; then
  echo "Refusing to run outside CI: this wipes $LANTERN_DATA_DIR" >&2
  exit 1
fi

trap cleanup EXIT

pkill -x Lantern 2>/dev/null || true
rm -rf "$LANTERN_DATA_DIR"
mkdir -p "$LANTERN_LOG_DIR"
mkdir -p "$ARTIFACT_DIR"

# The macOS app sets up Radiance natively at launch and selects staging when
# this marker file exists (see FilePath.isRadianceEnv()).
touch "$LANTERN_DATA_DIR/.radiance_env"

capture_checkout_screenshot &
SCREENSHOT_WATCHER_PID=$!

flutter test \
  "$TEST_PATH" \
  -d macos \
  --reporter=expanded \
  --dart-define=DISABLE_SYSTEM_TRAY=true
