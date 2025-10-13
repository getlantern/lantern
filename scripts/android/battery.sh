#!/usr/bin/env bash
set -euo pipefail

PKG=${PKG:-org.getlantern.lantern}
ACT=${ACT:-.MainActivity}
DUR=${DUR:-30}
OUT=${OUT:-dumps/batt-$(date +%Y%m%d-%H%M%S)}
STOP_ACTION=${STOP_ACTION:-org.getlantern.START_STOP}

mkdir -p "$OUT"

# Reset stats
adb shell am force-stop "$PKG" || true
adb shell dumpsys batterystats --reset
adb shell cmd battery unplug

echo "Launching app…"
adb shell am start -n "$PKG/$ACT"

echo "Exercise the app for $DUR sec"
sleep "$DUR"

echo "Stopping VPN/service"
adb shell am broadcast -a "$STOP_ACTION" -p "$PKG" || true

echo "Restoring charging state…"
adb shell cmd battery reset

echo "Dumping stats…"
adb shell dumpsys batterystats --charged > "$OUT/batterystats.txt"

grep -n "Estimated power use" -n "$OUT/batterystats.txt" -n | head -n 1 | cut -d: -f1 | \
  xargs -I{} sed -n '{} , +50p' "$OUT/batterystats.txt" > "$OUT/estimated-power.txt" || true


echo "Wrote:"
echo "  - $OUT/batterystats.txt"
echo "  - $OUT/estimated-power.txt"