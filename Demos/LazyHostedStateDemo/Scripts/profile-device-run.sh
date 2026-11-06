#!/bin/bash
# Records one run of the demo's built-in scroll script on a physical device.
#
# Usage: Scripts/profile-device-run.sh <device-udid> <path-to-built.app> <label> <baseline|hosted> <0|1 purge> <template|none>
#   template "none" launches without Instruments, for in-app frame-pacing numbers with no recording overhead.
# Output: Profiling/device/<label>_<template>.{trace,metrics.json,record.log}
# Build the Release app first:
#   xcodebuild build -project LazyHostedStateDemo.xcodeproj -scheme LazyHostedStateDemo -configuration Release \
#     -destination "id=<udid>" -derivedDataPath <dir> -allowProvisioningUpdates
set -euo pipefail

UDID=$1; APP=$2; LABEL=$3; MODE=$4; PURGE=$5; TEMPLATE=$6
BUNDLE=com.demo.ios.LazyHostedStateDemo
RUNID="$LABEL-$(date +%s)"  # the app echoes this into its report; stale reports are ignored
CYCLES=${CYCLES:-3}
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT="$HERE/Profiling/device"; mkdir -p "$OUT"
SAFE=$(echo "$TEMPLATE" | tr ' ' '-')
BASE="$OUT/${LABEL}_${SAFE}"
rm -rf "$BASE.trace" "$BASE.metrics.json"

xcrun devicectl device install app --device "$UDID" "$APP" > "$BASE.install.log" 2>&1
xcrun devicectl device process terminate --device "$UDID" --bundle-identifier "$BUNDLE" >/dev/null 2>&1 || true
# Remove any previous report so we only read this run's.
xcrun devicectl device process launch --help >/dev/null 2>&1
rm -rf "$OUT/.docs"; mkdir -p "$OUT/.docs"

ARGS=(-mode "$MODE" -purge "$PURGE" -purgeInterval 3 -autoscroll 1 -cycles "$CYCLES" -runID "$RUNID")
XPID=
if [ "$TEMPLATE" = "none" ]; then
  xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE" -- "${ARGS[@]}" > "$BASE.record.log" 2>&1
else
  xcrun xctrace record --template "$TEMPLATE" --device "$UDID" --launch "$BUNDLE" \
    --output "$BASE.trace" --time-limit 300s -- "${ARGS[@]}" > "$BASE.record.log" 2>&1 &
  XPID=$!
fi

fetch() {
  xcrun devicectl device copy from --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --source Documents/metrics-settled.json --destination "$BASE.metrics.json" >/dev/null 2>&1 \
    && grep -q "\"runID\":\"$RUNID\"" "$BASE.metrics.json" || { rm -f "$BASE.metrics.json"; return 1; }
}
for _ in $(seq 1 280); do
  sleep 3
  if [ -n "$XPID" ] && ! kill -0 $XPID 2>/dev/null; then echo "xctrace exited early: see $BASE.record.log" >&2; exit 1; fi
  fetch && break
done
[ -f "$BASE.metrics.json" ] || { echo "timed out waiting for settled report" >&2; [ -n "$XPID" ] && kill -INT $XPID; exit 1; }

if [ -n "$XPID" ]; then kill -INT $XPID; wait $XPID || true
else xcrun devicectl device process terminate --device "$UDID" --bundle-identifier "$BUNDLE" >/dev/null 2>&1 || true; fi
echo "$LABEL/$TEMPLATE done: $(cat "$BASE.metrics.json")"
