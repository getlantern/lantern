#!/usr/bin/env bash
set -euo pipefail

TEST_PATH="${TEST_PATH:-integration_test/payment/desktop_stripe_checkout_smoke_test.dart}"
ARTIFACT_DIR="${ARTIFACT_DIR:-smoke-artifacts/macos-payment-checkout}"
LANTERN_DATA_DIR="/Users/Shared/Lantern"
LANTERN_LOG_DIR="$LANTERN_DATA_DIR/Logs"
SCREENSHOT_PATH="$ARTIFACT_DIR/stripe-checkout.png"

cleanup() {
  local status=$?
  mkdir -p "$ARTIFACT_DIR"
  if [[ -d "$LANTERN_LOG_DIR" ]]; then
    cp -R "$LANTERN_LOG_DIR/." "$ARTIFACT_DIR/" 2>/dev/null || true
  fi
  rm -rf "$LANTERN_DATA_DIR"
  exit "$status"
}

trap cleanup EXIT

pkill -x Lantern 2>/dev/null || true
rm -rf "$LANTERN_DATA_DIR"
mkdir -p "$LANTERN_LOG_DIR"
mkdir -p "$ARTIFACT_DIR"

flutter test \
  "$TEST_PATH" \
  -d macos \
  --reporter=expanded \
  --dart-define=DISABLE_SYSTEM_TRAY=true \
  --dart-define=PAYMENT_SMOKE_SCREENSHOT_PATH="$SCREENSHOT_PATH" \
  --dart-define=RADIANCE_ENV=staging

if [[ ! -s "$SCREENSHOT_PATH" ]]; then
  echo "Stripe Checkout screenshot was not created" >&2
  exit 1
fi
