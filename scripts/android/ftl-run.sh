#!/usr/bin/env bash
#
# Runs the Android integration tests on Firebase Test Lab.
#
# Used by .github/workflows/firebase-test-lab.yml and runnable locally:
#
#   make android-ftl-test          # builds the APKs, then runs this script
#   scripts/android/ftl-run.sh    # runs against already-built APKs
#
# Requires the gcloud CLI authenticated against an account with access to the
# FTL_PROJECT project (`gcloud auth login`). Every setting can be overridden
# via environment variables, e.g.:
#
#   FTL_DEVICES="model=husky,version=35" scripts/android/ftl-run.sh

set -euo pipefail

FTL_PROJECT="${FTL_PROJECT:-lantern-android}"
FTL_APP_APK="${FTL_APP_APK:-build/app/outputs/apk/debug/app-debug.apk}"
FTL_TEST_APK="${FTL_TEST_APK:-build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk}"
FTL_RESULTS_BUCKET="${FTL_RESULTS_BUCKET:-lantern-android-ftl-results}"
FTL_RESULTS_DIR="${FTL_RESULTS_DIR:-ftl-local-$(whoami)-$(date -u +%Y%m%d-%H%M%S)}"
FTL_RESULTS_HISTORY="${FTL_RESULTS_HISTORY:-lantern-android-integration}"
FTL_TIMEOUT="${FTL_TIMEOUT:-20m}"
FTL_FLAKY_ATTEMPTS="${FTL_FLAKY_ATTEMPTS:-0}"
FTL_OUTPUT_LOG="${FTL_OUTPUT_LOG:-ftl-output.log}"
# Semicolon-separated device specs. Default: a physical Pixel 8 (shiba) plus
# an Arm virtual device — FTL runs all devices in a matrix in parallel, so a
# second device barely affects wall-clock time. Virtual models must be Arm
# (.arm) since the APK ships Arm-only native libs. For fast iteration on a
# single virtual device:
#   FTL_DEVICES="model=MediumPhone.arm,version=33,locale=en,orientation=portrait"
FTL_DEVICES="${FTL_DEVICES:-model=shiba,version=34,locale=en,orientation=portrait;model=MediumPhone.arm,version=33,locale=en,orientation=portrait}"

command -v gcloud >/dev/null || {
  echo "error: gcloud CLI not found — install the Google Cloud SDK" >&2
  exit 1
}

for apk in "$FTL_APP_APK" "$FTL_TEST_APK"; do
  [ -f "$apk" ] || {
    echo "error: $apk not found — build it first with: make android-integration-apks" >&2
    exit 1
  }
done

device_flags=()
IFS=';' read -ra devices <<<"$FTL_DEVICES"
for d in "${devices[@]}"; do
  device_flags+=(--device "$d")
done

echo "Running Firebase Test Lab (project=$FTL_PROJECT, results=gs://$FTL_RESULTS_BUCKET/$FTL_RESULTS_DIR)"
set -x
gcloud firebase test android run \
  --project "$FTL_PROJECT" \
  --type instrumentation \
  --app "$FTL_APP_APK" \
  --test "$FTL_TEST_APK" \
  "${device_flags[@]}" \
  --num-flaky-test-attempts="$FTL_FLAKY_ATTEMPTS" \
  --timeout "$FTL_TIMEOUT" \
  --results-bucket "$FTL_RESULTS_BUCKET" \
  --results-dir "$FTL_RESULTS_DIR" \
  --results-history-name "$FTL_RESULTS_HISTORY" \
  2>&1 | tee "$FTL_OUTPUT_LOG"
